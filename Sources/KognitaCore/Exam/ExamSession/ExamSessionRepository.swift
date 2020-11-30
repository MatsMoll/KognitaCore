//
//  ExamSessionRepository.swift
//  KognitaCore
//
//  Created by Mats Mollestad on 06/11/2020.
//

import Foundation
import KognitaModels
import FluentSQL
import FluentKit
import Vapor

public protocol ExamSessionRepository {
    func create(for examID: Exam.ID, by user: User) -> EventLoopFuture<ExamSession>

    func extend(session: ExamSession.ID, for user: User) -> EventLoopFuture<Void>

    func submit(_ submit: MultipleChoiceTask.Submit, sessionID: Exam.ID, by user: User) -> EventLoopFuture<TaskSessionResult<[MultipleChoiceTaskChoice.Result]>>
    func submit(_ submit: TypingTask.Submit, sessionID: Exam.ID, by user: User) -> EventLoopFuture<Void>

    func find(_ id: Int) -> EventLoopFuture<ExamSession>

    func subjectFor(sessionID: ExamSession.ID) -> EventLoopFuture<Subject>

    func taskID(index: Int, in sessionID: ExamSession.ID) -> EventLoopFuture<Task.ID>

    func getResult(for sessionID: ExamSession.ID) -> EventLoopFuture<[Sessions.TaskResult]>

    func currentActiveTask(in session: ExamSession.ID) -> EventLoopFuture<TaskType>
    func taskAt(index: Int, in sessionID: ExamSession.ID) -> EventLoopFuture<TaskType>

    func sessionWith(id: ExamSession.ID, isOwnedBy userID: User.ID) -> EventLoopFuture<Bool>
    func goalProgress(in sessionID: ExamSession.ID) -> EventLoopFuture<Int>
}

extension ExamSession {
    struct DatabaseRepository: ExamSessionRepository {

        let database: Database
        let repositories: RepositoriesRepresentable

        var multipleChoiceRepository: MultipleChoiseTaskRepository { repositories.multipleChoiceTaskRepository }
        var typingTaskRepository: TypingTaskRepository { repositories.typingTaskRepository }
        var taskResultRepository: TaskResultRepositoring { repositories.taskResultRepository }

        func create(for examID: Exam.ID, by user: User) -> EventLoopFuture<ExamSession> {
            Exam.DatabaseModel.query(on: database)
                .join(children: \Exam.DatabaseModel.$tasks)
                .filter(\.$id == examID)
                .all(TaskDatabaseModel.self, \.$id)
                .flatMap { taskIDs in

                    guard taskIDs.isEmpty == false else {
                        return database.eventLoop.future(error: Abort(.badRequest, reason: "Exam with id: \(examID) contains no tasks"))
                    }

                    let session = TaskSession(userID: user.id)
                    return session.create(on: database)
                        .flatMapThrowing {
                            try ExamSession.DatabaseModel(
                                id: session.requireID(),
                                examID: examID,
                                numberOfTaskGoal: min(5, taskIDs.count)
                            )
                        }
                        .flatMap { session in
                            session
                                .create(on: database)
                                .failableFlatMap {
                                    try taskIDs.enumerated().map { (index, taskID) in
                                        try TaskSession.Pivot.Task(
                                            sessionID: session.requireID(),
                                            taskID: taskID,
                                            index: index + 1
                                        )
                                        .create(on: database)
                                    }
                                    .flatten(on: database.eventLoop)
                                    .transform(to: session)
                                    .content()
                            }
                        }
                }
        }

        func extend(session id: ExamSession.ID, for user: User) -> EventLoopFuture<Void> {
            TaskSession.find(id, on: database)
                .unwrap(or: Abort(.badRequest))
                .flatMapThrowing { session in
                    guard session.$user.id == user.id else {
                        throw Abort(.forbidden)
                    }
                }.flatMap {
                    ExamSession.DatabaseModel.find(id, on: database)
                        .unwrap(or: Abort(.badRequest))
                }.flatMap { session in
                    session.numberOfTaskGoal += 5
                    return session.save(on: database)
                }
        }

        func submit(_ submit: MultipleChoiceTask.Submit, sessionID: Exam.ID, by user: User) -> EventLoopFuture<TaskSessionResult<[MultipleChoiceTaskChoice.Result]>> {

            sessionWith(id: sessionID, isOwnedBy: user.id)
                .ifFalse(throw: Abort(.forbidden))
                .flatMap {
                    get(MultipleChoiceTask.DatabaseModel.self, at: submit.taskIndex, for: sessionID, isCompleted: false)
                }
                .flatMap { task in
                    multipleChoiceRepository
                        .create(answer: submit, sessionID: sessionID)
                        .failableFlatMap { _ in
                            try multipleChoiceRepository
                                .evaluate(submit.choises, for: task.requireID())
                    }
                    .failableFlatMap { result in
                        let submitResult = try TaskSubmitResult(
                            submit: submit,
                            result: result,
                            taskID: task.requireID()
                        )
                        return taskResultRepository.createResult(from: submitResult, userID: user.id, with: sessionID)
                            .failableFlatMap { _ in
                                try markAsComplete(taskID: task.requireID(), in: sessionID)
                            }
                            .transform(to: result)
                    }
                }
                .flatMap { (result: TaskSessionResult<[MultipleChoiceTaskChoice.Result]>) in
                    goalProgress(in: sessionID)
                        .map { progress in
                            result.progress = Double(progress)
                            return result
                    }
                }
        }

        func submit(_ submit: TypingTask.Submit, sessionID: Exam.ID, by user: User) -> EventLoopFuture<Void> {

            return sessionWith(id: sessionID, isOwnedBy: user.id)
                .ifFalse(throw: Abort(.forbidden))
                .flatMap {
                    self.get(FlashCardTask.self, at: submit.taskIndex, for: sessionID)
                }.failableFlatMap { task in
                    self.update(submit, in: sessionID, userID: user.id)
                        .failableFlatMap { actionTaken in
                            guard case .created(result: _) = actionTaken else {
                                return database.eventLoop.future()
                            }
                            return try typingTaskRepository
                                .createAnswer(for: task.requireID(), withTextSubmittion: submit.answer)
                                .failableFlatMap { answer in
                                    try save(answer: answer, to: sessionID)
                                }
                                .failableFlatMap {
                                    try markAsComplete(taskID: task.requireID(), in: sessionID)
                                }
                    }
                }
        }

        private func save(answer: TaskAnswer, to sessionID: Sessions.ID) throws -> EventLoopFuture<Void> {
            return try TaskSessionAnswer(
                sessionID: sessionID,
                taskAnswerID: answer.requireID()
            )
            .create(on: database)
        }

        public func update(_ submit: TypingTask.Submit, in sessionID: PracticeSession.ID, userID: User.ID) -> EventLoopFuture<UpdateResultOutcom> {
            TaskSession.Pivot.Task.query(on: database)
                .filter(\TaskSession.Pivot.Task.$session.$id == sessionID)
                .filter(\TaskSession.Pivot.Task.$index       == submit.taskIndex)
                .first(TaskSession.Pivot.Task.self)
                .unwrap(or: Abort(.badRequest))
                .flatMap { (task: TaskSession.Pivot.Task) in
                    taskResultRepository.updateResult(
                        with: TaskSubmitResultRepresentableWrapper(
                            taskID: task.$task.id,
                            score: ScoreEvaluater.shared.compress(score: submit.knowledge, range: 0...4),
                            timeUsed: submit.timeUsed
                        ),
                        userID: userID,
                        with: sessionID
                    )
            }
        }

        public func subjectFor(sessionID: ExamSession.ID) -> EventLoopFuture<Subject> {
            TaskSession.Pivot.Task.query(on: database)
                .filter(\.$session.$id == sessionID)
                .all(\.$task.$id)
                .flatMap { taskIDs in
                    repositories.subjectRepository.subjectIDFor(taskIDs: taskIDs)
                }
                .flatMap { subjectID in
                    repositories.subjectRepository.find(subjectID, or: Abort(.internalServerError))
                }
        }

        func get<T: Model>(_ taskType: T.Type, at index: Int, for sessionID: ExamSession.ID, isCompleted: Bool? = nil) -> EventLoopFuture<T> where T.IDValue == Int {
            var query = TaskSession.Pivot.Task.query(on: database)
                .filter(\TaskSession.Pivot.Task.$session.$id == sessionID)
                .filter(\TaskSession.Pivot.Task.$index == index)
                .join(T.self, on: \TaskSession.Pivot.Task.$task.$id == \T._$id)

            if let isCompleted = isCompleted {
                query = query.filter(\.$isCompleted == isCompleted)
            }
            return query
                .first(T.self)
                .unwrap(or: Abort(.badRequest))
        }

        func markAsComplete(taskID: Task.ID, in sessionID: PracticeSession.ID) -> EventLoopFuture<Void> {
            return TaskSession.Pivot.Task
                .query(on: database)
                .filter(\.$session.$id == sessionID)
                .filter(\TaskSession.Pivot.Task.$task.$id == taskID)
                .first()
                .unwrap(or: Abort(.internalServerError, reason: "Unable to find pivot when registering submit"))
                .flatMap { pivot in
                    pivot.isCompleted = true
                    return pivot.save(on: self.database)
            }
        }

        func find(_ id: Int) -> EventLoopFuture<ExamSession> {
            ExamSession.DatabaseModel.find(id, on: database)
                .unwrap(or: Abort(.badRequest))
                .content()
        }

        func taskID(index: Int, in sessionID: ExamSession.ID) -> EventLoopFuture<Int> {
            TaskSession.Pivot.Task.query(on: database)
                .filter(\.$index == index)
                .filter(\.$session.$id == sessionID)
                .first()
                .unwrap(or: Abort(.badRequest))
                .map { $0.$task.id }
        }

        func getResult(for sessionID: ExamSession.ID) -> EventLoopFuture<[Sessions.TaskResult]> {
            guard let sql = database as? SQLDatabase else {
                return database.eventLoop.future(error: Abort(.internalServerError))
            }
            return sql.select()
                .column(\Topic.DatabaseModel.$name, as: "topicName")
                .column(\Topic.DatabaseModel.$id, as: "topicID")
                .column(\TaskSession.Pivot.Task.$index, as: "taskIndex")
                .column(\TaskResult.DatabaseModel.$createdAt, as: "date")
                .column(\TaskResult.DatabaseModel.$resultScore, as: "score")
                .column(\TaskResult.DatabaseModel.$timeUsed, as: "timeUsed")
                .column(\TaskResult.DatabaseModel.$revisitDate, as: "revisitDate")
                .column(\TaskResult.DatabaseModel.$isSetManually, as: "isSetManually")
                .column(\TaskDatabaseModel.$question, as: "question")
                .from(TaskSession.Pivot.Task.schema)
                .join(parent: \TaskSession.Pivot.Task.$task)
                .join(parent: \TaskDatabaseModel.$subtopic)
                .join(parent: \Subtopic.DatabaseModel.$topic)
                .join(from: \TaskDatabaseModel.$id, to: \TaskResult.DatabaseModel.$task.$id)
                .where(SQLColumn("sessionID", table: TaskResult.DatabaseModel.schema), .equal, SQLBind(sessionID))
                .where(SQLColumn("sessionID", table: TaskSession.Pivot.Task.schema), .equal, SQLBind(sessionID))
                .all(decoding: Sessions.TaskResult.self)
        }

        func currentActiveTask(in sessionID: ExamSession.ID) -> EventLoopFuture<TaskType> {
            TaskSession.Pivot.Task.query(on: database)
                .join(parent: \TaskSession.Pivot.Task.$task)
                .join(MultipleChoiceTask.DatabaseModel.self, on: \MultipleChoiceTask.DatabaseModel.$id == \TaskDatabaseModel.$id, method: .left)
                .join(parent: \TaskDatabaseModel.$exam, method: .left)
                .sort(\TaskSession.Pivot.Task.$index, .descending)
                .filter(\.$session.$id == sessionID)
                .first(TaskDatabaseModel.self, MultipleChoiceTask.DatabaseModel?.self, Exam.DatabaseModel?.self)
                .unwrap(or: Abort(.internalServerError))
                .map { TaskType(content: $0) }
        }

        func taskAt(index: Int, in sessionID: PracticeSession.ID) -> EventLoopFuture<TaskType> {
            TaskSession.Pivot.Task.query(on: database)
                .join(parent: \TaskSession.Pivot.Task.$task)
                .join(MultipleChoiceTask.DatabaseModel.self, on: \MultipleChoiceTask.DatabaseModel.$id == \TaskDatabaseModel.$id, method: .left)
                .join(parent: \TaskDatabaseModel.$exam, method: .left)
                .filter(\.$session.$id == sessionID)
                .filter(\.$index == index)
                .first(TaskDatabaseModel.self, MultipleChoiceTask.DatabaseModel?.self, Exam.DatabaseModel?.self)
                .unwrap(or: Abort(.internalServerError))
                .map { TaskType(content: $0) }
        }

        func sessionWith(id: ExamSession.ID, isOwnedBy userID: User.ID) -> EventLoopFuture<Bool> {
            TaskSession.find(id, on: database)
                .unwrap(or: Abort(.badRequest))
                .map { $0.$user.id == userID }
        }

        func goalProgress(in sessionID: PracticeSession.ID) -> EventLoopFuture<Int> {

            return TaskSession.Pivot.Task
                .query(on: database)
                .filter(\.$session.$id == sessionID)
                .filter(\.$isCompleted == true)
                .count()
                .flatMap { numberOfCompletedTasks in
                    ExamSession.DatabaseModel.find(sessionID, on: database)
                        .unwrap(or: Abort(.badRequest))
                        .map { session in
                            Int((Double(numberOfCompletedTasks * 100) / Double(session.numberOfTaskGoal)).rounded())
                    }
            }
        }
    }
}
