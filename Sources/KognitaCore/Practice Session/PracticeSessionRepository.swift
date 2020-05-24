//
//  PracticeSessionRepository.swift
//  KognitaCore
//
//  Created by Mats Mollestad on 12/04/2019.
//

import FluentPostgreSQL
import FluentSQL
import Vapor

public protocol PracticeSessionRepository: CreateModelRepository
    where
    CreateData == PracticeSession.Create.Data,
    CreateResponse == PracticeSession.Create.Response {
    func getSessions(for user: User) throws -> EventLoopFuture<[PracticeSession.HighOverview]>
    func extend(session: PracticeSessionRepresentable, for user: User) throws -> EventLoopFuture<Void>
    func submit(_ submit: MultipleChoiseTask.Submit, in session: PracticeSessionRepresentable, by user: User) throws -> EventLoopFuture<TaskSessionResult<[MultipleChoiseTaskChoise.Result]>>
    func submit(_ submit: FlashCardTask.Submit, in session: PracticeSessionRepresentable, by user: User) throws -> EventLoopFuture<TaskSessionResult<FlashCardTask.Submit>>
    func currentActiveTask(in session: PracticeSession) throws -> EventLoopFuture<TaskType>
    func end(_ session: PracticeSessionRepresentable, for user: User) throws -> EventLoopFuture<PracticeSessionRepresentable>
}

extension PracticeSession {
    public struct DatabaseRepository: DatabaseConnectableRepository {
        public let conn: DatabaseConnectable
        private var flashCardRepository: some FlashCardTaskRepository { FlashCardTask.DatabaseRepository(conn: conn) }
        private var multipleChoiseRepository: some MultipleChoiseTaskRepository { MultipleChoiseTask.DatabaseRepository(conn: conn) }
        private var subjectRepository: some SubjectRepositoring { Subject.DatabaseRepository(conn: conn) }
        private var userRepository: some UserRepository { User.DatabaseRepository(conn: conn) }
        private var subtopicRepository: some SubtopicRepositoring { Subtopic.DatabaseRepository(conn: conn) }
    }
}

extension PracticeSession.DatabaseRepository: PracticeSessionRepository {

    public enum Errors: Error {
        case noAssignedTask
        case nextTaskNotAssigned
        case incorrectTaskType
        case noMoreTasks
    }

    public func create(from content: PracticeSession.Create.Data, by user: User?) throws -> EventLoopFuture<PracticeSession.Create.Response> {

        guard let user = user else {
            throw Abort(.unauthorized)
        }

        if let topicIDs = content.topicIDs {
            return subjectRepository
                .subjectIDFor(topicIDs: Array(topicIDs))
                .flatMap { subjectID in

                    try self.userRepository
                        .canPractice(user: user, subjectID: subjectID)
                        .flatMap {

                            try self.create(
                                topicIDs: topicIDs,
                                numberOfTaskGoal: content.numberOfTaskGoal,
                                user: user
                            )
                    }
            }
        } else if let subtopicIDs = content.subtopicsIDs {

            return subjectRepository
                .subjectIDFor(subtopicIDs: Array(subtopicIDs))
                .flatMap { subjectID in

                    try self.userRepository
                        .canPractice(user: user, subjectID: subjectID)
                        .flatMap {

                            try self.create(
                                subtopicIDs: subtopicIDs,
                                numberOfTaskGoal: content.numberOfTaskGoal,
                                user: user
                            )
                    }
            }
        } else {
            throw Abort(.badRequest)
        }
    }

    func create(topicIDs: Set<Topic.ID>, numberOfTaskGoal: Int, user: User) throws -> EventLoopFuture<PracticeSession.Create.Response> {

        guard topicIDs.count > 0 else {
            throw Abort(.badRequest)
        }
        return topicIDs.map {
            self.subtopicRepository
                .subtopics(with: $0)
        }
        .flatten(on: conn)
        .flatMap { subtopics in
            let subtopicIDs = Set(subtopics.flatMap { $0 }.compactMap { $0.id })
            return try self.create(subtopicIDs: subtopicIDs, numberOfTaskGoal: numberOfTaskGoal, user: user)
        }
    }

    func create(subtopicIDs: Set<Subtopic.ID>, numberOfTaskGoal: Int, user: User) throws -> EventLoopFuture<PracticeSession.Create.Response> {

        guard subtopicIDs.count > 0 else {
            throw Abort(.badRequest)
        }
        return conn.transaction(on: .psql) { conn in

            try TaskSession(userID: user.requireID())
                .create(on: conn)
                .flatMap { superSession in

                    try PracticeSession.DatabaseModel(sessionID: superSession.requireID(), numberOfTaskGoal: numberOfTaskGoal)
                        .create(on: conn)
                        .flatMap { session in

                            try subtopicIDs.map {
                                try PracticeSession.Pivot.Subtopic(subtopicID: $0, session: session)
                                    .create(on: conn)
                                }
                                .flatten(on: conn)
                                .flatMap { _ in

                                    try self
                                        .assignTask(to: session.representable(with: superSession))
                                        .map { PracticeSession(model: session) }
                            }
                        }
            }
        }
    }

    public func subtopics(in session: PracticeSessionRepresentable) throws -> EventLoopFuture<[Subtopic]> {

        return try PracticeSession.Pivot.Subtopic
            .query(on: conn)
            .filter(\.sessionID == session.requireID())
            .join(\Subtopic.id, to: \PracticeSession.Pivot.Subtopic.subtopicID)
            .decode(Subtopic.self)
            .all()
    }

    public func assignedTasks(in session: PracticeSessionRepresentable) throws -> EventLoopFuture<[Task]> {

        return try PracticeSession.Pivot.Task
            .query(on: conn)
            .filter(\.sessionID == session.requireID())
            .join(\Task.id, to: \PracticeSession.Pivot.Task.taskID)
            .decode(Task.self)
            .all()
    }

    func uncompletedTasks(in session: PracticeSessionRepresentable) throws -> EventLoopFuture<SessionTasks> {

        return try subtopics(in: session)
            .flatMap { subtopics in

                try self
                    .assignedTasks(in: session)
                    .flatMap { assignedTasks in

                        try Task.query(on: self.conn)
                            .filter(
                                FilterOperator.make(
                                    \Task.id,
                                    PostgreSQLDatabase.queryFilterMethodNotInSubset,
                                    assignedTasks.map { try $0.requireID() }
                                )
                            )
                            .filter(\.subtopicID ~~ subtopics.map { try $0.requireID() })
                            .filter(\.isTestable == false)
                            .all()
                            .map { uncompletedTasks in

                                SessionTasks(
                                    uncompletedTasks: uncompletedTasks,
                                    assignedTasks: assignedTasks
                                )
                        }
                }
        }
    }

    public func assignTask(to session: PracticeSessionRepresentable) throws -> EventLoopFuture<Void> {

        return conn.databaseConnection(to: .psql).flatMap { psqlConn in

            let newRepo = PracticeSession.DatabaseRepository(conn: psqlConn)

            // 1/3 chanse of assigning a random task
            if Int.random(in: 1...3) == 3 {
                return try newRepo
                    .assignUncompletedTask(to: session)
            } else {
                return try TaskResult.DatabaseRepository
                    .getSpaceRepetitionTask(for: session, on: psqlConn)
                    .flatMap { repetitionTask in

                        guard let task = repetitionTask else {
                            return try newRepo
                                .assignUncompletedTask(to: session)
                        }

                        return try newRepo
                            .currentTaskIndex(in: session)
                            .flatMap { taskIndex in

                                try PracticeSession.Pivot.Task
                                    .create(session: session, taskID: task.taskID, index: taskIndex + 1, on: psqlConn)
                                    .transform(to: ())
                        }
                }
            }
        }
    }

    public func assignUncompletedTask(to session: PracticeSessionRepresentable) throws -> EventLoopFuture<Void> {

        return try uncompletedTasks(in: session)
            .flatMap { tasks in

                guard let task = tasks.uncompletedTasks.randomElement() else {
                    throw Errors.noMoreTasks
                }

                return try PracticeSession.Pivot.Task
                    .create(session: session, task: task, index: tasks.assignedTasks.count + 1, on: self.conn)
                    .transform(to: ())
        }
    }

    public func currentTaskIndex(in session: PracticeSessionRepresentable) throws -> EventLoopFuture<Int> {

        return try TaskResult.query(on: conn)
            .filter(\.sessionID == session.requireID())
            .count()
    }

    public func currentActiveTask(in session: PracticeSession) throws -> EventLoopFuture<TaskType> {

        conn.databaseConnection(to: .psql).flatMap { conn in
            try conn.select()
                .all(table: Task.self)
                .all(table: MultipleChoiseTask.self)
                .from(PracticeSession.Pivot.Task.self)
                .where(\PracticeSession.Pivot.Task.sessionID == session.id)
                .orderBy(\PracticeSession.Pivot.Task.index, .descending)
                .join(\PracticeSession.Pivot.Task.taskID, to: \Task.id)
                .join(\Task.id, to: \MultipleChoiseTask.id, method: .left)
                .first(decoding: Task.self, MultipleChoiseTask?.self)
                .unwrap(or: Abort(.internalServerError))
                .map { taskContent in
                    TaskType(content: taskContent)
            }
        }
    }

    public func taskAt(index: Int, in sessionID: PracticeSession.ID, on conn: PostgreSQLConnection) throws -> EventLoopFuture<TaskType> {

        return conn.select()
            .all(table: Task.self)
            .all(table: MultipleChoiseTask.self)
            .from(PracticeSession.Pivot.Task.self)
            .where(\PracticeSession.Pivot.Task.sessionID == sessionID)
            .where(\PracticeSession.Pivot.Task.index == index)
            .orderBy(\PracticeSession.Pivot.Task.index, .descending)
            .join(\PracticeSession.Pivot.Task.taskID, to: \Task.id)
            .join(\Task.id, to: \MultipleChoiseTask.id, method: .left)
            .first(decoding: Task.self, MultipleChoiseTask?.self)
            .unwrap(or: Abort(.badRequest))
            .map { taskContent in
                TaskType(content: taskContent)
        }
    }

    public func taskID(index: Int, in sessionID: PracticeSession.ID) -> EventLoopFuture<Task.ID> {

        PracticeSession.Pivot.Task
            .query(on: conn)
            .filter(\.index == index)
            .filter(\.sessionID == sessionID)
            .first()
            .unwrap(or: Abort(.badRequest))
            .map { $0.taskID }
    }
}

extension PracticeSession.DatabaseRepository {

    public func submit(_ submit: MultipleChoiseTask.Submit, in session: PracticeSessionRepresentable, by user: User) throws -> EventLoopFuture<TaskSessionResult<[MultipleChoiseTaskChoise.Result]>> {

        guard try user.requireID() == session.userID else {
            throw Abort(.forbidden)
        }

        return try get(MultipleChoiseTask.self, at: submit.taskIndex, for: session).flatMap { task in

            try self
                .multipleChoiseRepository
                .create(answer: submit, sessionID: session.requireID())
                .flatMap { _ in

                    try self
                        .multipleChoiseRepository
                        .evaluate(submit.choises, for: task)
                        .flatMap { result in

                            let submitResult = try TaskSubmitResult(
                                submit: submit,
                                result: result,
                                taskID: task.requireID()
                            )

                            return try self
                                .register(submitResult, result: result, in: session, by: user)
                                .flatMap { _ in

                                    try self
                                        .goalProgress(in: session)
                                        .map { progress in
                                            result.progress = Double(progress)
                                            return result
                                    }
                            }
                    }
            }
        }
    }

    public func submit(_ submit: FlashCardTask.Submit, in session: PracticeSessionRepresentable, by user: User) throws -> EventLoopFuture<TaskSessionResult<FlashCardTask.Submit>> {

        guard try user.requireID() == session.userID else {
            throw Abort(.forbidden)
        }

        return try get(FlashCardTask.self, at: submit.taskIndex, for: session).flatMap { task in

            FlashCardTask.DatabaseRepository(conn: self.conn)
                .createAnswer(for: task, with: submit)
                .flatMap { answer in

                    try self.update(submit, in: session)
                        .map { _ in
                            TaskSessionResult(result: submit, score: 0, progress: 0)
                    }
                    .catchFlatMap { _ in
                        try self
                            .save(answer: answer, to: session.requireID())
                            .flatMap {

                                let score = ScoreEvaluater.shared
                                    .compress(score: submit.knowledge, range: 0...4)

                                let result = TaskSessionResult(
                                    result: submit,
                                    score: score,
                                    progress: 0
                                )

                                let submitResult = try TaskSubmitResult(
                                    submit: submit,
                                    result: result,
                                    taskID: task.requireID()
                                )

                                return try self
                                    .register(submitResult, result: result, in: session, by: user)
                                    .flatMap { _ in

                                        try self
                                            .goalProgress(in: session)
                                            .map { progress in
                                                result.progress = Double(progress)
                                                return result
                                        }
                                }
                        }
                    }
            }
        }
    }

    public func update(_ submit: FlashCardTask.Submit, in session: PracticeSessionRepresentable) throws -> EventLoopFuture<Void> {
        try PracticeSession.Pivot.Task.query(on: conn)
            .filter(\TaskResult.sessionID                   == session.requireID())
            .filter(\PracticeSession.Pivot.Task.sessionID   == session.requireID())
            .filter(\PracticeSession.Pivot.Task.index       == submit.taskIndex)
            .join(\TaskResult.taskID, to: \PracticeSession.Pivot.Task.taskID)
            .join(\FlashCardTask.id, to: \TaskResult.taskID)
            .decode(TaskResult.self)
            .first()
            .unwrap(or: Abort(.badRequest))
            .flatMap { (result: TaskResult) in
                result.resultScore = ScoreEvaluater.shared.compress(score: submit.knowledge, range: 0...4)
                result.isSetManually = true
                return result.save(on: self.conn)
                    .transform(to: ())
        }
    }

    public func get<T: PostgreSQLModel>(_ taskType: T.Type, at index: Int, for session: PracticeSessionRepresentable) throws -> EventLoopFuture<T> {

        return try PracticeSession.Pivot.Task
            .query(on: conn)
            .filter(\PracticeSession.Pivot.Task.sessionID == session.requireID())
            .filter(\PracticeSession.Pivot.Task.index == index)
            .sort(\PracticeSession.Pivot.Task.index, .descending)
            .join(\T.id, to: \PracticeSession.Pivot.Task.taskID)
            .decode(T.self)
            .first()
            .unwrap(or: Abort(.badRequest))
    }

    func markAsComplete(taskID: Task.ID, in session: PracticeSessionRepresentable) throws -> EventLoopFuture<Void> {

        return try PracticeSession.Pivot.Task
            .query(on: conn)
            .filter(\.sessionID == session.requireID())
            .filter(\PracticeSession.Pivot.Task.taskID == taskID)
            .first()
            .unwrap(or: Abort(.internalServerError, reason: "Unable to find pivot when registering submit"))
            .flatMap { pivot in
                pivot.isCompleted = true
                return pivot
                    .save(on: self.conn)
                    .flatMap { _ in

                        try self.assignTask(to: session)
                }
        }
    }

    public func end(_ session: PracticeSessionRepresentable, for user: User) throws -> EventLoopFuture<PracticeSessionRepresentable> {

        guard try session.userID == user.requireID() else {
            throw Abort(.forbidden)
        }

        guard session.endedAt == nil else {
            return conn.future(session)
        }
        return session.end(on: conn)
    }

    public func goalProgress(in session: PracticeSessionRepresentable) throws -> EventLoopFuture<Int> {

        let goal = Double(session.numberOfTaskGoal)

        return try PracticeSession.Pivot.Task
            .query(on: conn)
            .filter(\.sessionID == session.requireID())
            .filter(\.isCompleted == true)
            .count()
            .map { (numberOfCompletedTasks) in
                Int((Double(numberOfCompletedTasks * 100) / goal).rounded())
        }
    }

    public func getCurrentTaskIndex(for sessionId: PracticeSession.ID) throws -> EventLoopFuture<Int> {

        return PracticeSession.Pivot.Task
            .query(on: conn)
            .filter(\PracticeSession.Pivot.Task.sessionID == sessionId)
            .sort(\PracticeSession.Pivot.Task.index, .descending)
            .first()
            .unwrap(or: Abort(.badRequest))
            .map { task in
                task.index
        }
    }

    public func getResult(for sessionID: PracticeSession.ID) throws -> EventLoopFuture<[PracticeSession.TaskResult]> {

        return conn.databaseConnection(to: .psql)
            .flatMap { conn in

                conn.select()
                    .column(\Topic.name, as: "topicName")
                    .column(\Topic.id, as: "topicID")
                    .column(\PracticeSession.Pivot.Task.index, as: "taskIndex")
                    .column(\TaskResult.createdAt, as: "date")
                    .column(\Task.question, as: "question")
                    .column(\TaskResult.resultScore, as: "score")
                    .column(\TaskResult.timeUsed, as: "timeUsed")
                    .column(\TaskResult.revisitDate, as: "revisitDate")
                    .column(\TaskResult.isSetManually, as: "isSetManually")
                    .from(PracticeSession.Pivot.Task.self)
                    .join(\PracticeSession.Pivot.Task.taskID, to: \Task.id)
                    .join(\Task.subtopicID, to: \Subtopic.id)
                    .join(\Subtopic.topicId, to: \Topic.id)
                    .join(\Task.id, to: \TaskResult.taskID)
                    .where(\TaskResult.sessionID == sessionID)
                    .where(\PracticeSession.Pivot.Task.sessionID == sessionID)
                    .all(decoding: PracticeSession.TaskResult.self)
        }
    }

    public func getAllSessions(by user: User) throws -> EventLoopFuture<[PracticeSession]> {

        return try PracticeSession.DatabaseModel
            .query(on: conn)
            .join(\TaskSession.id, to: \PracticeSession.DatabaseModel.id)
            .filter(\TaskSession.userID == user.requireID())
            .filter(\PracticeSession.DatabaseModel.endedAt != nil)
            .sort(\PracticeSession.DatabaseModel.createdAt, .descending)
            .all()
            .map {
                $0.map { PracticeSession(model: $0) }
        }
    }

    public static func getAllSessionsWithSubject(
        by user: User,
        on conn: PostgreSQLConnection
    ) throws -> EventLoopFuture<PracticeSession.HistoryList> {

        return try conn.select()
            .all(table: PracticeSession.DatabaseModel.self)
            .all(table: Subject.self)
            .from(PracticeSession.DatabaseModel.self)
            .join(\PracticeSession.DatabaseModel.id, to: \TaskSession.id)
            .join(\PracticeSession.DatabaseModel.id, to: \PracticeSession.Pivot.Subtopic.sessionID)
            .join(\PracticeSession.Pivot.Subtopic.subtopicID, to: \Subtopic.id)
            .join(\Subtopic.topicId, to: \Topic.id)
            .join(\Topic.subjectId, to: \Subject.id)
            .where(\PracticeSession.DatabaseModel.endedAt != nil)
            .where(\TaskSession.userID == user.requireID())
            .orderBy(\PracticeSession.DatabaseModel.createdAt, .descending)
            .groupBy(\PracticeSession.DatabaseModel.id)
            .groupBy(\Subject.id)
            .all(decoding: PracticeSession.self, Subject.self)
            .map { sessions in
                PracticeSession.HistoryList(
                    sessions: sessions.map { item in
                        PracticeSession.HistoryList.Session(
                            session: item.0,
                            subject: item.1
                        )
                    }
                )
        }
    }

    public func getSessions(for user: User) throws -> EventLoopFuture<[PracticeSession.HighOverview]> {

        conn.databaseConnection(to: .psql)
            .flatMap { conn in

                try conn.select()
                    .column(\Subject.name, as: "subjectName")
                    .column(\Subject.id, as: "subjectID")
                    .column(\PracticeSession.DatabaseModel.id, as: "id")
                    .column(\PracticeSession.DatabaseModel.createdAt, as: "createdAt")
                    .column(\PracticeSession.DatabaseModel.endedAt, as: "endedAt")
                    .from(PracticeSession.DatabaseModel.self)
                    .join(\PracticeSession.DatabaseModel.id, to: \TaskSession.id)
                    .join(\PracticeSession.DatabaseModel.id, to: \PracticeSession.Pivot.Subtopic.sessionID)
                    .join(\PracticeSession.Pivot.Subtopic.subtopicID, to: \Subtopic.id)
                    .join(\Subtopic.topicId, to: \Topic.id)
                    .join(\Topic.subjectId, to: \Subject.id)
                    .where(\PracticeSession.DatabaseModel.endedAt != nil)
                    .where(\TaskSession.userID == user.requireID())
                    .orderBy(\PracticeSession.DatabaseModel.createdAt, .descending)
                    .groupBy(\PracticeSession.DatabaseModel.id)
                    .groupBy(\Subject.id)
                    .all(decoding: PracticeSession.HighOverview.self)
        }
    }

    func register<T: Content>(_ submitResult: TaskSubmitResult, result: TaskSessionResult<T>, in session: PracticeSessionRepresentable, by user: User) throws -> EventLoopFuture<TaskResult> {

        return try TaskResult.DatabaseRepository
            .createResult(from: submitResult, userID: user.requireID(), with: session.requireID(), on: conn)
            .flatMap { result in

                try self.markAsComplete(taskID: submitResult.taskID, in: session)
                    .catchFlatMap { error in
                        switch error {
                        case PracticeSession.DatabaseRepository.Errors.noMoreTasks: return self.conn.future()
                        default: return self.conn.future(error: error)
                        }
                }.transform(to: result)
        }
    }

    public func cleanSessions() -> EventLoopFuture<Void> {

        return PracticeSession.DatabaseModel.query(on: conn)
            .filter(\.endedAt == nil)
            .all()
            .flatMap { sessions in
                sessions.map { session in
                    TaskResult.query(on: self.conn)
                        .filter(\.sessionID == session.id)
                        .sort(\.createdAt, .descending)
                        .first()
                        .flatMap { result in
                            guard let createdAt = result?.createdAt else {
                                return session.delete(on: self.conn)
                            }
                            session.endedAt = createdAt
                            return session.save(on: self.conn)
                                .transform(to: ())
                    }
                }.flatten(on: self.conn)
        }
    }

    public func getLatestUnfinnishedSessionPath(for user: User) throws -> EventLoopFuture<String?> {

        return try PracticeSession.DatabaseModel.query(on: conn)
            .join(\TaskSession.id, to: \PracticeSession.id)
            .filter(\TaskSession.userID == user.requireID())
            .filter(\PracticeSession.DatabaseModel.endedAt == nil)
            .sort(\PracticeSession.DatabaseModel.createdAt, .descending)
            .first()
            .flatMap { session in

                if let session = session {
                    return try self
                        .getCurrentTaskIndex(for: session.requireID())
                        .map(to: String?.self) { try session.pathFor(index: $0) }
                } else {
                    return self.conn.future(nil)
                }

        }
    }

    /// Returns the number of tasks in a session
    public func getNumberOfTasks(in session: PracticeSession) throws -> EventLoopFuture<Int> {

        return try PracticeSession.Pivot.Subtopic.query(on: conn)
            .join(\Task.subtopicID, to: \PracticeSession.Pivot.Subtopic.subtopicID)
            .filter(\PracticeSession.Pivot.Subtopic.sessionID == session.id)
            .count()
    }

    public func save(answer: TaskAnswer, to sessionID: PracticeSession.ID) throws -> EventLoopFuture<Void> {
        try TaskSessionAnswer(
            sessionID: sessionID,
            taskAnswerID: answer.requireID()
        )
        .create(on: conn)
        .transform(to: ())
    }

    public func extend(session: PracticeSessionRepresentable, for user: User) throws -> EventLoopFuture<Void> {
        guard try session.userID == user.requireID() else {
            throw Abort(.forbidden)
        }
        return session.extendSession(with: 5, on: conn)
            .transform(to: ())
    }
}

struct SessionTasks {
    let uncompletedTasks: [Task]
    let assignedTasks: [Task]
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
