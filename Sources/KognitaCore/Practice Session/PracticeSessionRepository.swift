//
//  PracticeSessionRepository.swift
//  KognitaCore
//
//  Created by Mats Mollestad on 12/04/2019.
//

import FluentSQL
import FluentPostgresDriver
import Fluent
import Vapor

extension TypingTask.Submit: Content, TaskSubmitable {}

public protocol PracticeSessionRepository {
    func create(from content: PracticeSession.Create.Data, by user: User?) throws -> EventLoopFuture<PracticeSession.Create.Response>
    func getSessions(for user: User) throws -> EventLoopFuture<[PracticeSession.Overview]>
    func extend(session: PracticeSessionRepresentable, for user: User) throws -> EventLoopFuture<Void>
    func submit(_ submit: MultipleChoiceTask.Submit, in session: PracticeSessionRepresentable, by user: User) throws -> EventLoopFuture<TaskSessionResult<[MultipleChoiceTaskChoice.Result]>>
    func submit(_ submit: TypingTask.Submit, in session: PracticeSessionRepresentable, by user: User) throws -> EventLoopFuture<TaskSessionResult<TypingTask.Submit>>
    func currentActiveTask(in session: PracticeSession) throws -> EventLoopFuture<TaskType>
    func end(_ session: PracticeSessionRepresentable, for user: User) -> EventLoopFuture<PracticeSessionRepresentable>
    func end(sessionID: PracticeSession.ID, for user: User) -> EventLoopFuture<Void>
    func find(_ id: Int) -> EventLoopFuture<PracticeSessionRepresentable>
    func taskID(index: Int, in sessionID: PracticeSession.ID) -> EventLoopFuture<Task.ID>
    func getResult(for sessionID: PracticeSession.ID) throws -> EventLoopFuture<[Sessions.TaskResult]>
    func taskAt(index: Int, in sessionID: PracticeSession.ID) throws -> EventLoopFuture<TaskType>
    func sessionWith(id: PracticeSession.ID, isOwnedBy userID: User.ID) -> EventLoopFuture<Bool>
    func goalProgress(in sessionID: PracticeSession.ID) -> EventLoopFuture<Int>
}

extension PracticeSession {
    public struct DatabaseRepository: DatabaseConnectableRepository {

        init(database: Database, repositories: RepositoriesRepresentable) {
            self.database = database
            self.flashCardRepository = repositories.typingTaskRepository
            self.multipleChoiceRepository = repositories.multipleChoiceTaskRepository
            self.subjectRepository = repositories.subjectRepository
            self.userRepository = repositories.userRepository
            self.subtopicRepository = repositories.subtopicRepository
            self.taskResultRepository = repositories.taskResultRepository
        }

        init(database: Database, repository: DatabaseRepository) {
            self.database = database
            self.flashCardRepository = repository.flashCardRepository
            self.multipleChoiceRepository = repository.multipleChoiceRepository
            self.subjectRepository = repository.subjectRepository
            self.userRepository = repository.userRepository
            self.subtopicRepository = repository.subtopicRepository
            self.taskResultRepository = repository.taskResultRepository
        }

        public let database: Database

        private let flashCardRepository: FlashCardTaskRepository
        private let multipleChoiceRepository: MultipleChoiseTaskRepository
        private let subjectRepository: SubjectRepositoring
        private let userRepository: UserRepository
        private let subtopicRepository: SubtopicRepositoring
        private let taskResultRepository: TaskResultRepositoring
    }
}

extension PracticeSession.DatabaseRepository: PracticeSessionRepository {

    public enum Errors: Error {
        case noAssignedTask
        case nextTaskNotAssigned
        case incorrectTaskType
        case noMoreTasks
    }

    public func end(sessionID: PracticeSession.ID, for user: User) -> EventLoopFuture<Void> {
        find(sessionID)
            .flatMap { session in
                self.end(session, for: user)
        }
        .transform(to: ())
    }

    public func find(_ id: Int) -> EventLoopFuture<PracticeSessionRepresentable> {
        PracticeSession.PracticeParameter.resolveWith(id, database: database)
    }

    public func sessionWith(id: PracticeSession.ID, isOwnedBy userID: User.ID) -> EventLoopFuture<Bool> {
        TaskSession.query(on: database)
            .filter(\.$user.$id == userID)
            .filter(\.$id == id)
            .first()
            .map { $0 != nil }
    }

    public func create(from content: PracticeSession.Create.Data, by user: User?) throws -> EventLoopFuture<PracticeSession.Create.Response> {

        guard let user = user else {
            throw Abort(.unauthorized)
        }

        if let topicIDs = content.topicIDs {
            return subjectRepository
                .subjectIDFor(topicIDs: Array(topicIDs))
                .failableFlatMap { subjectID in
                    self.userRepository
                        .canPractice(user: user, subjectID: subjectID)
                        .ifFalse(throw: Abort(.forbidden))
                }
                .failableFlatMap {
                    try self.create(
                        topicIDs: topicIDs,
                        content: content,
                        user: user
                    )
            }
        } else if let subtopicIDs = content.subtopicsIDs {

            return subjectRepository
                .subjectIDFor(subtopicIDs: Array(subtopicIDs))
                .failableFlatMap { subjectID in
                    self.userRepository
                        .canPractice(user: user, subjectID: subjectID)
                        .ifFalse(throw: Abort(.forbidden))
                }
                .failableFlatMap {
                    try self.create(
                        subtopicIDs: subtopicIDs,
                        content: content,
                        user: user
                    )
            }
        } else {
            throw Abort(.badRequest)
        }
    }

    func create(topicIDs: Set<Topic.ID>, content: PracticeSession.Create.Data, user: User) throws -> EventLoopFuture<PracticeSession.Create.Response> {

        guard topicIDs.count > 0 else {
            return database.eventLoop.future(error: Abort(.badRequest))
        }
        return topicIDs.map {
            self.subtopicRepository
                .subtopics(with: $0)
        }
        .flatten(on: database.eventLoop)
        .failableFlatMap { subtopics in
            let subtopicIDs = Set(subtopics.flatMap { $0 }.compactMap { $0.id })
            return try self.create(subtopicIDs: subtopicIDs, content: content, user: user)
        }
    }

    func create(subtopicIDs: Set<Subtopic.ID>, content: PracticeSession.Create.Data, user: User) throws -> EventLoopFuture<PracticeSession.Create.Response> {

        guard subtopicIDs.count > 0 else {
            throw Abort(.badRequest)
        }
        let session = TaskSession(userID: user.id)

        return session.create(on: self.database)
            .flatMapThrowing {
                try PracticeSession.DatabaseModel(
                    sessionID: session.requireID(),
                    numberOfTaskGoal: content.numberOfTaskGoal,
                    useTypingTasks: content.useTypingTasks,
                    useMultipleChoiceTasks: content.useMultipleChoiceTasks,
                    addTasksLazely: true
                )
            }
            .flatMap { pracSession in
                return pracSession.create(on: self.database)
                    .flatMapThrowing { try session.requireID() }
                    .flatMap { sessionID in
                        subtopicIDs.map {
                            PracticeSession.Pivot.Subtopic(subtopicID: $0, sessionID: sessionID)
                                .create(on: self.database)
                        }
                        .flatten(on: self.database.eventLoop)
                        .failableFlatMap {
                            try self.assignTask(to: session.requireID())
                        }
                }
                .map { PracticeSession(model: pracSession) }
        }
    }

    public func subtopics(in session: PracticeSessionRepresentable) throws -> EventLoopFuture<[Subtopic]> {
        return try subtopics(in: session.requireID())
    }

    func subtopics(in sessionID: PracticeSession.ID) -> EventLoopFuture<[Subtopic]> {

        return PracticeSession.Pivot.Subtopic
            .query(on: database)
            .filter(\.$session.$id == sessionID)
            .join(parent: \PracticeSession.Pivot.Subtopic.$subtopic)
            .all(Subtopic.DatabaseModel.self)
            .flatMapEachThrowing { try $0.content() }
    }

    func assignedTasks(in session: PracticeSessionRepresentable) throws -> EventLoopFuture<[TaskDatabaseModel]> {
        return try self.assignedTasks(in: session.requireID())
    }

    func assignedTasks(in sessionID: PracticeSession.ID) -> EventLoopFuture<[TaskDatabaseModel]> {
        return PracticeSession.Pivot.Task
            .query(on: database)
            .filter(\.$session.$id == sessionID)
            .join(parent: \PracticeSession.Pivot.Task.$task)
            .all(TaskDatabaseModel.self)
    }

    func uncompletedTasks(in sessionID: PracticeSession.ID, session: PracticeSession.DatabaseModel) -> EventLoopFuture<SessionTasks> {

        return assignedTasks(in: sessionID)
            .flatMap { assignedTasks in

                subtopics(in: sessionID)
                    .flatMap { subtopics in

                        var query = TaskDatabaseModel.query(on: self.database)
                            .filter(\.$subtopic.$id ~~ subtopics.map { $0.id })
                            .filter(\.$id !~ assignedTasks.compactMap { $0.id })
                            .filter(\.$isTestable == false)

                        if session.useAllTaskTypes == false {
                            if session.useTypingTasks {
                                query = query.join(superclass: FlashCardTask.self, with: TaskDatabaseModel.self)
                            }
                            if session.useMultipleChoiceTasks {
                                query = query.join(superclass: MultipleChoiceTask.DatabaseModel.self, with: TaskDatabaseModel.self)
                            }
                        }

                        return query.all()
                }
                .map { SessionTasks(uncompletedTasks: $0, assignedTasks: assignedTasks) }
        }
    }

    public func assignTask(to session: PracticeSessionRepresentable) throws -> EventLoopFuture<Void> {
        try assignTask(to: session.requireID())
    }

    public func assignTask(to sessionID: PracticeSession.ID) throws -> EventLoopFuture<Void> {

        // 1/3 chance of assigning a random task
        if Int.random(in: 1...3) == 3 {
            return assignUncompletedTask(to: sessionID)
        } else {
            return owner(of: sessionID)
                .flatMap { userID in

                    self.taskResultRepository
                        .getSpaceRepetitionTask(for: userID, sessionID: sessionID)
                        .flatMap { repetitionTask in

                            guard let task = repetitionTask else {
                                return self.assignUncompletedTask(to: sessionID)
                            }

                            return self.currentTaskIndex(in: sessionID)
                                .flatMap { taskIndex in

                                    PracticeSession.Pivot.Task
                                        .create(sessionID: sessionID, taskID: task.taskID, index: taskIndex + 1, on: self.database)
                                        .transform(to: ())
                            }
                    }
            }
        }
    }

    public func assignUncompletedTask(to session: PracticeSessionRepresentable) throws -> EventLoopFuture<Void> {
        try assignUncompletedTask(to: session.requireID())
    }

    public func assignUncompletedTask(to sessionID: PracticeSession.ID) -> EventLoopFuture<Void> {

        PracticeSession.DatabaseModel.find(sessionID, on: database)
            .unwrap(or: Abort(.badRequest))
            .flatMap { session in

                // Only assign tasks if the session is set to do it lazely
                return uncompletedTasks(in: sessionID, session: session)
                    .failableFlatMap { tasks in

                        guard let task = tasks.uncompletedTasks.randomElement() else {
                            throw Errors.noMoreTasks
                        }

                        return try PracticeSession.Pivot.Task
                            .create(sessionID: sessionID, taskID: task.requireID(), index: tasks.assignedTasks.count + 1, on: self.database)
                            .transform(to: ())
                }
            }
    }

    public func currentTaskIndex(in session: PracticeSessionRepresentable) throws -> EventLoopFuture<Int> {
        try self.currentTaskIndex(in: session.requireID())
    }

    public func currentTaskIndex(in sessionID: PracticeSession.ID) -> EventLoopFuture<Int> {
        return TaskResult.DatabaseModel.query(on: database)
            .filter(\.$session.$id == sessionID)
            .count()
    }

    public func currentActiveTask(in session: PracticeSession) throws -> EventLoopFuture<TaskType> {

        PracticeSession.Pivot.Task.query(on: database)
            .join(parent: \PracticeSession.Pivot.Task.$task)
            .join(MultipleChoiceTask.DatabaseModel.self, on: \MultipleChoiceTask.DatabaseModel.$id == \TaskDatabaseModel.$id, method: .left)
            .join(parent: \TaskDatabaseModel.$exam, method: .left)
            .sort(\PracticeSession.Pivot.Task.$index, .descending)
            .filter(\.$session.$id == session.id)
            .first(TaskDatabaseModel.self, MultipleChoiceTask.DatabaseModel?.self, Exam.DatabaseModel?.self)
            .unwrap(or: Abort(.internalServerError))
            .map { TaskType(content: $0) }
    }

    public func taskAt(index: Int, in sessionID: PracticeSession.ID) throws -> EventLoopFuture<TaskType> {

        PracticeSession.Pivot.Task.query(on: database)
            .join(parent: \PracticeSession.Pivot.Task.$task)
            .join(MultipleChoiceTask.DatabaseModel.self, on: \MultipleChoiceTask.DatabaseModel.$id == \TaskDatabaseModel.$id, method: .left)
            .join(parent: \TaskDatabaseModel.$exam, method: .left)
            .filter(\.$session.$id == sessionID)
            .filter(\.$index == index)
            .first(TaskDatabaseModel.self, MultipleChoiceTask.DatabaseModel?.self, Exam.DatabaseModel?.self)
            .unwrap(or: Abort(.internalServerError))
            .map { TaskType(content: $0) }
    }

    public func taskID(index: Int, in sessionID: PracticeSession.ID) -> EventLoopFuture<Task.ID> {

        PracticeSession.Pivot.Task.query(on: database)
            .filter(\.$index == index)
            .filter(\.$session.$id == sessionID)
            .first()
            .unwrap(or: Abort(.badRequest))
            .map { $0.$task.id }
    }
}

extension PracticeSession.DatabaseRepository {

    func owner(of sessionID: PracticeSession.ID) -> EventLoopFuture<User.ID> {
        TaskSession.query(on: database)
            .filter(\.$id == sessionID)
            .first()
            .unwrap(or: Abort(.badRequest))
            .map { $0.$user.id }
    }

    public func submit(_ submit: MultipleChoiceTask.Submit, in session: PracticeSessionRepresentable, by user: User) throws -> EventLoopFuture<TaskSessionResult<[MultipleChoiceTaskChoice.Result]>> {

        guard let sessionID = try? session.requireID() else {
            return database.eventLoop.future(error: Abort(.badRequest))
        }
        guard user.id == session.userID else {
            return database.eventLoop.future(error: Abort(.forbidden))
        }

        return get(MultipleChoiceTask.DatabaseModel.self, at: submit.taskIndex, for: sessionID)
            .flatMap { (task: MultipleChoiceTask.DatabaseModel) in

                self.multipleChoiceRepository
                    .create(answer: submit, sessionID: sessionID)
                    .failableFlatMap { _ in
                        try self.multipleChoiceRepository
                            .evaluate(submit.choises, for: task.requireID())
                }
                .failableFlatMap { result in
                    let submitResult = try TaskSubmitResult(
                        submit: submit,
                        result: result,
                        taskID: task.requireID()
                    )
                    return self.register(submitResult, result: result, in: sessionID, by: user)
                        .transform(to: result)
                }
        }
        .flatMap { (result: TaskSessionResult<[MultipleChoiceTaskChoice.Result]>) in
            self.goalProgress(in: sessionID)
                .map { progress in
                    result.progress = Double(progress)
                    return result
            }
        }
    }

    public func submit(_ submit: TypingTask.Submit, in session: PracticeSessionRepresentable, by user: User) throws -> EventLoopFuture<TaskSessionResult<TypingTask.Submit>> {

        guard let sessionID = try? session.requireID() else {
            return database.eventLoop.future(error: Abort(.badRequest))
        }

        return sessionWith(id: sessionID, isOwnedBy: user.id)
            .ifFalse(throw: Abort(.forbidden))
            .flatMap {
                self.get(FlashCardTask.self, at: submit.taskIndex, for: sessionID)
            }.flatMap { task in
                self.update(submit, in: sessionID, userID: user.id)
                    .failableFlatMap { actionTaken in
                        guard case .created(result: _) = actionTaken else {
                            return database.eventLoop.future(TaskSessionResult(result: submit, score: 0, progress: 0))
                        }

                        return try self.flashCardRepository
                            .createAnswer(for: task.requireID(), withTextSubmittion: submit.answer)
                            .failableFlatMap { answer in

                                try self.save(answer: answer, to: sessionID)
                                    .failableFlatMap {

                                        try markAsComplete(taskID: task.requireID(), in: sessionID)
                                            .flatMapError { error in
                                                switch error {
                                                case PracticeSession.DatabaseRepository.Errors.noMoreTasks: return self.database.eventLoop.future()
                                                default: return self.database.eventLoop.future(error: error)
                                                }
                                        }
                                    }
                        }
                        .flatMap {
                            goalProgress(in: sessionID)
                                .map { progress in
                                    TaskSessionResult(
                                        result: submit,
                                        score: submit.knowledge,
                                        progress: Double(progress)
                                    )
                            }
                        }
                }
        }
    }

    public func update(_ submit: TypingTask.Submit, in sessionID: PracticeSession.ID, userID: User.ID) -> EventLoopFuture<UpdateResultOutcom> {
        PracticeSession.Pivot.Task.query(on: database)
            .filter(\PracticeSession.Pivot.Task.$session.$id   == sessionID)
            .filter(\PracticeSession.Pivot.Task.$index       == submit.taskIndex)
            .first(PracticeSession.Pivot.Task.self)
            .unwrap(or: Abort(.badRequest))
            .flatMap { (task: PracticeSession.Pivot.Task) in
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

    func get<T: Model>(_ taskType: T.Type, at index: Int, for sessionID: PracticeSession.ID) -> EventLoopFuture<T> where T.IDValue == Int {
        return PracticeSession.Pivot.Task.query(on: database)
            .filter(\PracticeSession.Pivot.Task.$session.$id == sessionID)
            .filter(\PracticeSession.Pivot.Task.$index == index)
            .sort(\PracticeSession.Pivot.Task.$index, .descending)
            .join(T.self, on: \PracticeSession.Pivot.Task.$task.$id == \T._$id)
            .first(T.self)
            .unwrap(or: Abort(.badRequest))
    }

    func markAsComplete(taskID: Task.ID, in sessionID: PracticeSession.ID) -> EventLoopFuture<Void> {

        return PracticeSession.Pivot.Task
            .query(on: database)
            .filter(\.$session.$id == sessionID)
            .filter(\PracticeSession.Pivot.Task.$task.$id == taskID)
            .first()
            .unwrap(or: Abort(.internalServerError, reason: "Unable to find pivot when registering submit"))
            .flatMap { pivot in
                pivot.isCompleted = true
                return pivot.save(on: self.database)
        }
        .failableFlatMap {
            try self.assignTask(to: sessionID)
        }
    }

    public func end(_ session: PracticeSessionRepresentable, for user: User) -> EventLoopFuture<PracticeSessionRepresentable> {

        guard session.userID == user.id else {
            return database.eventLoop.future(error: Abort(.forbidden))
        }
        guard session.endedAt == nil else {
            return self.database.eventLoop.future(session)
        }
        return session.end(on: self.database)
    }

    public func goalProgress(in sessionID: PracticeSession.ID) -> EventLoopFuture<Int> {

        return PracticeSession.Pivot.Task
            .query(on: database)
            .filter(\.$session.$id == sessionID)
            .filter(\.$isCompleted == true)
            .count()
            .flatMap { numberOfCompletedTasks in
                PracticeSession.DatabaseModel.find(sessionID, on: self.database)
                    .unwrap(or: Abort(.badRequest))
                    .map { session in
                        Int((Double(numberOfCompletedTasks * 100) / Double(session.numberOfTaskGoal)).rounded())
                }
        }
    }

    public func getResult(for sessionID: PracticeSession.ID) throws -> EventLoopFuture<[Sessions.TaskResult]> {

        guard let sql = database as? SQLDatabase else {
            return database.eventLoop.future(error: Abort(.internalServerError))
        }

        return sql.select()
            .column(\Topic.DatabaseModel.$name, as: "topicName")
            .column(\Topic.DatabaseModel.$id, as: "topicID")
            .column(\PracticeSession.Pivot.Task.$index, as: "taskIndex")
            .column(\TaskResult.DatabaseModel.$createdAt, as: "date")
            .column(\TaskResult.DatabaseModel.$resultScore, as: "score")
            .column(\TaskResult.DatabaseModel.$timeUsed, as: "timeUsed")
            .column(\TaskResult.DatabaseModel.$revisitDate, as: "revisitDate")
            .column(\TaskResult.DatabaseModel.$isSetManually, as: "isSetManually")
            .column(\TaskDatabaseModel.$question, as: "question")
            .from(PracticeSession.Pivot.Task.schema)
            .join(parent: \PracticeSession.Pivot.Task.$task)
            .join(parent: \TaskDatabaseModel.$subtopic)
            .join(parent: \Subtopic.DatabaseModel.$topic)
            .join(from: \TaskDatabaseModel.$id, to: \TaskResult.DatabaseModel.$task.$id)
            .where(SQLColumn("sessionID", table: TaskResult.DatabaseModel.schema), .equal, SQLBind(sessionID))
            .where(SQLColumn("sessionID", table: PracticeSession.Pivot.Task.schema), .equal, SQLBind(sessionID))
            .all(decoding: Sessions.TaskResult.self)
    }

    public func getSessions(for user: User) throws -> EventLoopFuture<[PracticeSession.Overview]> {

        guard let sql = database as? SQLDatabase else {
            return database.eventLoop.future(error: Abort(.internalServerError))
        }

        return sql.select()
            .column(\Subject.DatabaseModel.$name, as: "subjectName")
            .column(\Subject.DatabaseModel.$id, as: "subjectID")
            .column(\PracticeSession.DatabaseModel.$id, as: "id")
            .column(\PracticeSession.DatabaseModel.$createdAt, as: "createdAt")
            .column(\PracticeSession.DatabaseModel.$endedAt, as: "endedAt")
            .from(PracticeSession.DatabaseModel.schema)
            .join(from: \PracticeSession.DatabaseModel.$id, to: \TaskSession.$id)
            .join(from: \PracticeSession.DatabaseModel.$id, to: \PracticeSession.Pivot.Subtopic.$session.$id)
            .join(parent: \PracticeSession.Pivot.Subtopic.$subtopic)
            .join(parent: \Subtopic.DatabaseModel.$topic)
            .join(parent: \Topic.DatabaseModel.$subject)
            .where(SQLRaw("\"endedAt\" IS NOT NULL"))
            .where("userID", .equal, user.id)
            .orderBy(SQLColumn("createdAt", table: PracticeSession.DatabaseModel.schemaOrAlias), SQLDirection.descending)
            .groupBy(\PracticeSession.DatabaseModel.$id)
            .groupBy(\Subject.DatabaseModel.$id)
            .all(decoding: PracticeSession.Overview.self)
    }

    func register<T: Content>(_ submitResult: TaskSubmitResult, result: TaskSessionResult<T>, in session: PracticeSessionRepresentable, by user: User) throws -> EventLoopFuture<TaskResult> {
        try register(submitResult, result: result, in: session.requireID(), by: user)
    }

    func register<T: Content>(_ submitResult: TaskSubmitResult, result: TaskSessionResult<T>, in sessionID: PracticeSession.ID, by user: User) -> EventLoopFuture<TaskResult> {

        return taskResultRepository
            .createResult(from: submitResult, userID: user.id, with: sessionID)
            .flatMap { result in
                self.markAsComplete(taskID: submitResult.taskID, in: sessionID)
                    .flatMapError { error in
                        switch error {
                        case PracticeSession.DatabaseRepository.Errors.noMoreTasks: return self.database.eventLoop.future()
                        default: return self.database.eventLoop.future(error: error)
                        }
                }
                .transform(to: result)
        }
    }

    public func save(answer: TaskAnswer, to sessionID: PracticeSession.ID) throws -> EventLoopFuture<Void> {
        return try TaskSessionAnswer(
            sessionID: sessionID,
            taskAnswerID: answer.requireID()
        )
        .create(on: database)
    }

    public func extend(session: PracticeSessionRepresentable, for user: User) throws -> EventLoopFuture<Void> {
        guard session.userID == user.id else {
            return database.eventLoop.future(error: Abort(.forbidden))
        }
        return session.extendSession(with: 5, on: database)
            .transform(to: ())
    }
}

struct SessionTasks {
    let uncompletedTasks: [TaskDatabaseModel]
    let assignedTasks: [TaskDatabaseModel]
}

extension PracticeSession {
    init(model: PracticeSession.DatabaseModel) {
        self.init(
            id: model.id ?? 0,
            numberOfTaskGoal: model.numberOfTaskGoal,
            createdAt: model.createdAt ?? Date(),
            endedAt: model.endedAt
        )
    }
}

extension PracticeSession.DatabaseModel {
    public var practiceSession: PracticeSession { .init(model: self) }
}
