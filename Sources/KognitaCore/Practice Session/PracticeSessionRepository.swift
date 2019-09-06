//
//  PracticeSessionRepository.swift
//  KognitaCore
//
//  Created by Mats Mollestad on 12/04/2019.
//

import FluentPostgreSQL
import FluentSQL
import Vapor

extension PracticeSession {
    
    public struct Create : KognitaRequestData {
        
        public struct Data : Decodable {
            /// The number of task to complete in a session
            public let numberOfTaskGoal: Int

            /// The topic id's for the tasks to map
            public let subtopicsIDs: Set<Subtopic.ID>
        }
        
        public typealias Response = PracticeSession
        
        public struct WebResponse : Content {
            /// A redirection to the session
            public let redirectionUrl: String
            
            public init(redirectionUrl: String) {
                self.redirectionUrl = redirectionUrl
            }
        }
    }
    
    public typealias Edit = Create
}


extension PracticeSession {
    
    public final class Repository : KognitaCRUDRepository {
        
        public typealias Model = PracticeSession
        
        public static var shared = Repository()
    }
}


extension PracticeSession.Repository {

    public enum Errors: Error {
        case noAssignedTask
        case nextTaskNotAssigned
        case incorrectTaskType
        case noMoreTasks
    }

    public func create(from content: PracticeSession.Create.Data, by user: User?, on conn: DatabaseConnectable) throws -> EventLoopFuture<PracticeSession.Create.Response> {
        
        guard content.subtopicsIDs.count > 0 else {
            throw Abort(.badRequest)
        }
        guard let user = user else {
            throw Abort(.unauthorized)
        }
        return conn.transaction(on: .psql) { conn in

            try PracticeSession(user: user, numberOfTaskGoal: content.numberOfTaskGoal)
                .create(on: conn)
                .flatMap { session in

                    try content.subtopicsIDs.map {
                        try PracticeSession.Pivot.Subtopic(subtopicID: $0, session: session)
                            .create(on: conn)
                        }
                        .flatten(on: conn)
                        .flatMap { _ in

                            try session
                                .assignNextTask(on: conn)
                                .transform(to: session)
                    }
                }
        }
    }
    
    public func subtopics(in session: PracticeSession, on conn: DatabaseConnectable) throws -> Future<[Subtopic]> {
        return try session.subtopics
            .query(on: conn)
            .all()
    }
    
    public func assignedTasks(in session: PracticeSession, on conn: DatabaseConnectable) throws -> Future<[Task]> {
        return try session.assignedTasks
            .query(on: conn)
            .all()
    }
    
    func uncompletedTasks(in session: PracticeSession, on conn: DatabaseConnectable) throws -> Future<SessionTasks> {
        return try subtopics(in: session, on: conn)
            .flatMap { subtopics in
            
                try PracticeSession.repository
                    .assignedTasks(in: session, on: conn)
                    .flatMap { assignedTasks in
                        
                        try Task.query(on: conn)
                            .filter(
                                FilterOperator.make(
                                    \Task.id,
                                    PostgreSQLDatabase.queryFilterMethodNotInSubset,
                                    assignedTasks.map { try $0.requireID() }
                                )
                            )
                            .filter(\.subtopicId ~~ subtopics.map { try $0.requireID() })
                            .all()
                            .map { uncompletedTasks in
                                
                                return SessionTasks(
                                    uncompletedTasks: uncompletedTasks,
                                    assignedTasks: assignedTasks
                                )
                        }
                }
        }
    }
    
    public func assignTask(to session: PracticeSession, on conn: DatabaseConnectable) throws -> Future<Void> {
        return try uncompletedTasks(in: session, on: conn)
            .flatMap { tasks in

                guard let task = tasks.uncompletedTasks.randomElement() else {
                    throw Errors.noMoreTasks
                }
                
                return try PracticeSession.Pivot.Task
                    .create(session: session, task: task, index: tasks.assignedTasks.count + 1, on: conn)
                    .transform(to: ())
        }
    }
    
    public func edit(_ model: PracticeSession, to content: PracticeSession.Create.Data, by user: User, on conn: DatabaseConnectable) throws -> EventLoopFuture<PracticeSession.Create.Response> {
        throw Abort(.internalServerError)
    }
    
    public func currentActiveTask(in session: PracticeSession, on conn: PostgreSQLConnection) throws -> Future<(Task, MultipleChoiseTask?, NumberInputTask?)> {
        return try conn.select()
            .all(table: Task.self)
            .all(table: MultipleChoiseTask.self)
            .all(table: NumberInputTask.self)
            .from(PracticeSession.Pivot.Task.self)
            .where(\PracticeSession.Pivot.Task.sessionID == session.requireID())
            .orderBy(\PracticeSession.Pivot.Task.index, .descending)
            .join(\PracticeSession.Pivot.Task.taskID, to: \Task.id)
            .join(\Task.id, to: \MultipleChoiseTask.id, method: .left)
            .join(\Task.id, to: \NumberInputTask.id, method: .left)
            .first(decoding: Task.self, MultipleChoiseTask?.self, NumberInputTask?.self)
            .unwrap(or: Abort(.internalServerError))
    }
}

extension PracticeSession.Repository {
    
    public func goalProgress(for session: PracticeSession, on conn: DatabaseConnectable) throws -> Future<Int> {

        let goal = Double(session.numberOfTaskGoal)

        return try session.assignedTasks
            .pivots(on: conn)
            .filter(\.isCompleted == true)
            .count()
            .map { (numberOfCompletedTasks) in
                Int((Double(numberOfCompletedTasks * 100) / goal).rounded())
        }
    }

    public func submitInputTask(_ submit: NumberInputTask.Submit.Data, in session: PracticeSession, by user: User, on conn: DatabaseConnectable) throws -> Future<PracticeSessionResult<NumberInputTask.Submit.Response>> {

        guard try user.requireID() == session.userID else {
            throw Abort(.forbidden)
        }

        return try getCurrent(NumberInputTask.self, for: session, on: conn).flatMap { task in
            let result = NumberInputTask.Repository.shared
                .evaluate(submit, for: task)

            let submitResult = try TaskSubmitResult(
                submit: submit,
                result: result,
                taskID: task.requireID()
            )

            return try PracticeSession.repository
                .register(submitResult, result: result, in: session, by: user, on: conn)
                .flatMap { _ in
                        
                        try session.goalProgress(on: conn)
                            .map { progress in
                                result.progress = Double(progress)
                                return result
                        }
                }
        }
    }

    public func submitMultipleChoise(_ submit: MultipleChoiseTask.Submit, in session: PracticeSession, by user: User, on conn: DatabaseConnectable) throws -> Future<PracticeSessionResult<[MultipleChoiseTaskChoise.Result]>> {

        guard try user.requireID() == session.userID else {
            throw Abort(.forbidden)
        }

        return try getCurrent(MultipleChoiseTask.self, for: session, on: conn).flatMap { task in

            try MultipleChoiseTask.repository
                .evaluate(submit, for: task, on: conn)
                .flatMap { result in

                    let submitResult = try TaskSubmitResult(
                        submit: submit,
                        result: result,
                        taskID: task.requireID()
                    )

                    return try PracticeSession.repository
                        .register(submitResult, result: result, in: session, by: user, on: conn)
                        .flatMap { _ in
                            
                            try session.goalProgress(on: conn)
                                .map { progress in
                                    result.progress = Double(progress)
                                    return result
                            }
                    }
            }
        }
    }

    public func submitFlashCard(
        _ submit: FlashCardTask.Submit,
        in session: PracticeSession,
        by user: User,
        on conn: DatabaseConnectable
    ) throws -> Future<PracticeSessionResult<FlashCardTask.Submit>> {

        guard try user.requireID() == session.userID else {
            throw Abort(.forbidden)
        }
        
        return try getCurrent(FlashCardTask.self, for: session, on: conn).flatMap { task in

            let score = ScoreEvaluater.shared
                .compress(score: submit.knowledge, range: 0...4)

            let result = PracticeSessionResult(
                result:                 submit,
                score:                  score,
                progress:               0
            )

            let submitResult = try TaskSubmitResult(
                submit: submit,
                result: result,
                taskID: task.requireID()
            )

            return try PracticeSession.repository
                .register(submitResult, result: result, in: session, by: user, on: conn)
                .flatMap { _ in

                    try session.goalProgress(on: conn)
                        .map { progress in
                            result.progress = Double(progress)
                            return result
                    }
            }
        }
    }

    public func getCurrent<T: PostgreSQLModel>(_ taskType: T.Type, for session: PracticeSession, on conn: DatabaseConnectable) throws -> Future<T> {
        

        return try PracticeSession.Pivot.Task
            .query(on: conn)
            .filter(\PracticeSession.Pivot.Task.sessionID == session.requireID())
            .sort(\PracticeSession.Pivot.Task.index, .descending)
            .join(\T.id, to: \PracticeSession.Pivot.Task.taskID)
            .decode(T.self)
            .first()
            .unwrap(or: Abort(.badRequest))
    }

    func markAsComplete(taskID: Task.ID, in session: PracticeSession, on conn: DatabaseConnectable) throws -> Future<PracticeSession.Pivot.Task> {

        return try session.assignedTasks
            .pivots(on: conn)
            .filter(\PracticeSession.Pivot.Task.taskID == taskID)
            .first()
            .unwrap(or: Abort(.internalServerError, reason: "Unable to find pivot when registering submit"))
            .flatMap { pivot in
                pivot.isCompleted = true
                return pivot
                    .save(on: conn)
                    .flatMap { pivot in

                        try session
                            .assignNextTask(on: conn)
                            .transform(to: pivot)
                }
        }
    }

    public func end(_ session: PracticeSession, for user: User, on conn: DatabaseConnectable) throws -> Future<PracticeSession> {
        guard try session.userID == user.requireID() else {
            throw Abort(.forbidden)
        }
        guard session.endedAt == nil else {
            return conn.future(session)
        }
        session.endedAt = Date()
        return session.save(on: conn)
    }

    public func goalProgress(in session: PracticeSession, on conn: DatabaseConnectable) throws -> Future<Int> {

        let goal = Double(session.numberOfTaskGoal)

        return try session.assignedTasks
            .pivots(on: conn)
            .filter(\.isCompleted == true)
            .count()
            .map { (numberOfCompletedTasks) in
                Int((Double(numberOfCompletedTasks * 100) / goal).rounded())
        }
    }

    public func getCurrentTaskIndex(for sessionId: PracticeSession.ID, on conn: DatabaseConnectable) throws -> Future<Int> {
        
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

    public func getResult(for session: PracticeSession, on conn: DatabaseConnectable) throws -> Future<[PSTaskResult]> {

        return try TaskResult.query(on: conn)
            .filter(\TaskResult.sessionID == session.requireID())
            .join(\Task.id, to: \TaskResult.taskID)
            .join(\Subtopic.id, to: \Task.subtopicId)
            .join(\Topic.id, to: \Subtopic.topicId)
            .alsoDecode(Task.self)
            .alsoDecode(Topic.self).all()
            .map { tasks in
                tasks.map { PSTaskResult(task: $0.0.1, topic: $0.1, result: $0.0.0) }
        }
    }

    public func getAllSessions(by user: User, on conn: DatabaseConnectable) throws -> Future<[PracticeSession]> {
        return try PracticeSession
            .query(on: conn)
            .filter(\.userID == user.requireID())
            .filter(\.endedAt != nil)
            .sort(\.createdAt, .descending)
            .all()
    }

    func register<T: Content>(_ submitResult: TaskSubmitResult, result: PracticeSessionResult<T>, in session: PracticeSession, by user: User, on conn: DatabaseConnectable) throws -> Future<TaskResult> {

        return try PracticeSession.repository
            .markAsComplete(taskID: submitResult.taskID, in: session, on: conn)
            .flatMap { _ in
                
                try TaskResultRepository.shared
                    .createResult(from: submitResult, by: user, on: conn, in: session)
        }
        
//        guard let taskID = session.currentTaskID else {
//            throw Abort(.internalServerError)
//        }
//        return try PracticeSession.repository
//            .markAsComplete(taskID: taskID, in: session, on: conn)
//            .flatMap { _ in
//
//                try TaskResultRepository.shared
//                    .createResult(from: submitResult, by: user, on: conn, in: session)
//                    .flatMap { _ in
//
//                        try PracticeSession.repository
//                            .goalProgress(in: session, on: conn)
//                            .map { progress in
//                                result.progress = Double(progress)
//                                return result
//                        }
//                }
//        }
    }


    public func cleanSessions(on conn: DatabaseConnectable) -> Future<Void> {

//        let maxSessionLimit = Calendar.current.date(byAdding: .hour, value: -20, to: Date()) ?? Date().addingTimeInterval(-20 * 60 * 60)

        return PracticeSession.query(on: conn)
            .filter(\.endedAt == nil)
            .all()
            .flatMap { sessions in
                sessions.map { session in
                    TaskResult.query(on: conn)
                        .filter(\.sessionID == session.id)
                        .sort(\.createdAt, .descending)
                        .first()
                        .flatMap { result in
                            guard let createdAt = result?.createdAt else {
                                return session.delete(on: conn)
                            }
                            session.endedAt = createdAt
                            return session.save(on: conn)
                                .transform(to: ())
                    }
                }.flatten(on: conn)
        }
    }


    public func getLatestUnfinnishedSessionPath(for user: User, on conn: DatabaseConnectable) throws -> Future<String?> {

        return try PracticeSession.query(on: conn)
            .filter(\PracticeSession.userID == user.requireID())
            .filter(\PracticeSession.endedAt == nil)
            .sort(\.createdAt, .descending)
            .first()
            .flatMap { session in

                if let session = session {
                    return try session
                        .getCurrentTaskIndex(conn)
                        .map(to: String?.self) { try session.pathFor(index: $0) }
                } else {
                    return conn.future(nil)
                }

        }
    }

    /// Returns the number of tasks in a session
    ///
    public func getNumberOfTasks(in session: PracticeSession, on conn: DatabaseConnectable) throws -> Future<Int> {

        return try PracticeSession.Pivot.Subtopic.query(on: conn)
            .join(\Task.subtopicId, to: \PracticeSession.Pivot.Subtopic.subtopicID)
            .filter(\PracticeSession.Pivot.Subtopic.sessionID == session.requireID())
            .count()
    }
}

struct SessionTasks {
    let uncompletedTasks: [Task]
    let assignedTasks: [Task]
}
