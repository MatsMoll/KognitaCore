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
            public let subtopicsIDs: Set<Subtopic.ID>?

            public let topicIDs: Set<Topic.ID>?
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
    }
}

extension PracticeSession {
    public struct HistoryList: Content {
        public struct Session: Content {
            public let session: PracticeSession
            public let subject: Subject
        }

        public let sessions: [Session]
    }
}


extension PracticeSession.Repository {

    public enum Errors: Error {
        case noAssignedTask
        case nextTaskNotAssigned
        case incorrectTaskType
        case noMoreTasks
    }

    public static func create(from content: PracticeSession.Create.Data, by user: User?, on conn: DatabaseConnectable) throws -> EventLoopFuture<PracticeSession.Create.Response> {

        guard let user = user else {
            throw Abort(.unauthorized)
        }

        if let topicIDs = content.topicIDs {
            return try create(topicIDs: topicIDs, numberOfTaskGoal: content.numberOfTaskGoal, user: user, on: conn)
        } else if let subtopicIDs = content.subtopicsIDs {
            return try create(subtopicIDs: subtopicIDs, numberOfTaskGoal: content.numberOfTaskGoal, user: user, on: conn)
        } else {
            throw Abort(.badRequest)
        }
    }

    static func create(topicIDs: Set<Topic.ID>, numberOfTaskGoal: Int, user: User, on conn: DatabaseConnectable) throws -> EventLoopFuture<PracticeSession.Create.Response> {
        guard topicIDs.count > 0 else {
            throw Abort(.badRequest)
        }
        return topicIDs.map {
            Subtopic.Repository.subtopics(with: $0, on: conn)
        }
        .flatten(on: conn)
        .flatMap { subtopics in
            let subtopicIDs = Set(subtopics.flatMap { $0 }.compactMap { $0.id })
            return try create(subtopicIDs: subtopicIDs, numberOfTaskGoal: numberOfTaskGoal, user: user, on: conn)
        }
    }

    static func create(subtopicIDs: Set<Subtopic.ID>, numberOfTaskGoal: Int, user: User, on conn: DatabaseConnectable) throws -> EventLoopFuture<PracticeSession.Create.Response> {
        guard subtopicIDs.count > 0 else {
            throw Abort(.badRequest)
        }
        return conn.transaction(on: .psql) { conn in

            try PracticeSession(user: user, numberOfTaskGoal: numberOfTaskGoal)
                .create(on: conn)
                .flatMap { session in

                    try subtopicIDs.map {
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
    
    public static func subtopics(in session: PracticeSession, on conn: DatabaseConnectable) throws -> Future<[Subtopic]> {
        return try session.subtopics
            .query(on: conn)
            .all()
    }
    
    public static func assignedTasks(in session: PracticeSession, on conn: DatabaseConnectable) throws -> Future<[Task]> {
        return try session.assignedTasks
            .query(on: conn)
            .all()
    }
    
    static func uncompletedTasks(in session: PracticeSession, on conn: DatabaseConnectable) throws -> Future<SessionTasks> {
        return try subtopics(in: session, on: conn)
            .flatMap { subtopics in
            
                try PracticeSession.Repository
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
                                
                                SessionTasks(
                                    uncompletedTasks: uncompletedTasks,
                                    assignedTasks: assignedTasks
                                )
                        }
                }
        }
    }
    
    public static func assignTask(to session: PracticeSession, on conn: DatabaseConnectable) throws -> Future<Void> {

        return conn.databaseConnection(to: .psql).flatMap { psqlConn in
            try TaskResultRepository
                .getFlowZoneTasks(for: session, on: psqlConn)
                .flatMap { flowTask in

                    guard let task = flowTask else {
                        return try PracticeSession.Repository
                            .assignUncompletedTask(to: session, on: psqlConn)
                    }

                    return try PracticeSession.Repository
                        .currentTaskIndex(in: session, on: psqlConn)
                        .flatMap { taskIndex in

                            try PracticeSession.Pivot.Task
                                .create(session: session, taskID: task.taskID, index: taskIndex + 1, on: psqlConn)
                                .transform(to: ())
                    }
            }
        }
    }

    public static func assignUncompletedTask(to session: PracticeSession, on conn: DatabaseConnectable) throws -> Future<Void> {
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
    
    public static func edit(_ model: PracticeSession, to content: PracticeSession.Create.Data, by user: User, on conn: DatabaseConnectable) throws -> EventLoopFuture<PracticeSession.Create.Response> {
        throw Abort(.internalServerError)
    }

    public static func currentTaskIndex(in session: PracticeSession, on conn: DatabaseConnectable) throws -> Future<Int> {
        return try TaskResult.query(on: conn)
            .filter(\.sessionID == session.requireID())
            .count()
    }
    
    public static func currentActiveTask(in session: PracticeSession, on conn: PostgreSQLConnection) throws -> Future<TaskType> {
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
            .map { taskContent in
                TaskType(content: taskContent)
        }
    }

    public static func taskAt(index: Int, in session: PracticeSession, on conn: PostgreSQLConnection) throws -> Future<TaskType> {
        return try conn.select()
            .all(table: Task.self)
            .all(table: MultipleChoiseTask.self)
            .all(table: NumberInputTask.self)
            .from(PracticeSession.Pivot.Task.self)
            .where(\PracticeSession.Pivot.Task.sessionID == session.requireID())
            .where(\PracticeSession.Pivot.Task.index == index)
            .orderBy(\PracticeSession.Pivot.Task.index, .descending)
            .join(\PracticeSession.Pivot.Task.taskID, to: \Task.id)
            .join(\Task.id, to: \MultipleChoiseTask.id, method: .left)
            .join(\Task.id, to: \NumberInputTask.id, method: .left)
            .first(decoding: Task.self, MultipleChoiseTask?.self, NumberInputTask?.self)
            .unwrap(or: Abort(.badRequest))
            .map { taskContent in
                TaskType(content: taskContent)
        }
    }

    public static func taskID(index: Int, in session: PracticeSession, on conn: DatabaseConnectable) throws -> Future<Task.ID> {
        try PracticeSession.Pivot.Task
            .query(on: conn)
            .filter(\.index == index)
            .filter(\.sessionID == session.requireID())
            .first()
            .unwrap(or: Abort(.badRequest))
            .map {
                $0.taskID
        }
    }
}

extension PracticeSession.Repository {
    
    public static func goalProgress(for session: PracticeSession, on conn: DatabaseConnectable) throws -> Future<Int> {

        let goal = Double(session.numberOfTaskGoal)

        return try session.assignedTasks
            .pivots(on: conn)
            .filter(\.isCompleted == true)
            .count()
            .map { (numberOfCompletedTasks) in
                Int((Double(numberOfCompletedTasks * 100) / goal).rounded())
        }
    }

    public static func submitInputTask(_ submit: NumberInputTask.Submit.Data, in session: PracticeSession, by user: User, on conn: DatabaseConnectable) throws -> Future<PracticeSessionResult<NumberInputTask.Submit.Response>> {

        guard try user.requireID() == session.userID else {
            throw Abort(.forbidden)
        }

        return try get(NumberInputTask.self, at: submit.taskIndex, for: session, on: conn).flatMap { task in
            let result = NumberInputTask.Repository
                .evaluate(submit, for: task)

            let submitResult = try TaskSubmitResult(
                submit: submit,
                result: result,
                taskID: task.requireID()
            )

            return try PracticeSession.Repository
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

    public static func submitMultipleChoise(_ submit: MultipleChoiseTask.Submit, in session: PracticeSession, by user: User, on conn: DatabaseConnectable) throws -> Future<PracticeSessionResult<[MultipleChoiseTaskChoise.Result]>> {

        guard try user.requireID() == session.userID else {
            throw Abort(.forbidden)
        }

        return try get(MultipleChoiseTask.self, at: submit.taskIndex, for: session, on: conn).flatMap { task in

            try MultipleChoiseTask.Repository
                .createAnswer(in: session.requireID(), with: submit, on: conn)
                .flatMap { _ in

                    try MultipleChoiseTask.Repository
                        .evaluate(submit, for: task, on: conn)
                        .flatMap { result in

                            let submitResult = try TaskSubmitResult(
                                submit: submit,
                                result: result,
                                taskID: task.requireID()
                            )

                            return try PracticeSession.Repository
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
    }

    public static func submitFlashCard(
        _ submit: FlashCardTask.Submit,
        in session: PracticeSession,
        by user: User,
        on conn: DatabaseConnectable
    ) throws -> Future<PracticeSessionResult<FlashCardTask.Submit>> {

        guard try user.requireID() == session.userID else {
            throw Abort(.forbidden)
        }
        
        return try get(FlashCardTask.self, at: submit.taskIndex, for: session, on: conn).flatMap { task in

            try FlashCardTask.Repository
                .createAnswer(in: session, for: task, with: submit, on: conn)
                .flatMap {

                    let score = ScoreEvaluater.shared
                        .compress(score: submit.knowledge, range: 0...4)

                    let result = PracticeSessionResult(
                        result:     submit,
                        score:      score,
                        progress:   0
                    )

                    let submitResult = try TaskSubmitResult(
                        submit: submit,
                        result: result,
                        taskID: task.requireID()
                    )

                    return try PracticeSession.Repository
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

    public static func get<T: PostgreSQLModel>(_ taskType: T.Type, at index: Int, for session: PracticeSession, on conn: DatabaseConnectable) throws -> Future<T> {
        

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

    static func markAsComplete(taskID: Task.ID, in session: PracticeSession, on conn: DatabaseConnectable) throws -> Future<Void> {

        return try session.assignedTasks
            .pivots(on: conn)
            .filter(\PracticeSession.Pivot.Task.taskID == taskID)
            .first()
            .unwrap(or: Abort(.internalServerError, reason: "Unable to find pivot when registering submit"))
            .flatMap { pivot in
                pivot.isCompleted = true
                return pivot
                    .save(on: conn)
                    .flatMap { _ in

                        try session
                            .assignNextTask(on: conn)
                }
        }
    }

    public static func end(_ session: PracticeSession, for user: User, on conn: DatabaseConnectable) throws -> Future<PracticeSession> {
        guard try session.userID == user.requireID() else {
            throw Abort(.forbidden)
        }
        guard session.endedAt == nil else {
            return conn.future(session)
        }
        session.endedAt = Date()
        return session.save(on: conn)
    }

    public static func goalProgress(in session: PracticeSession, on conn: DatabaseConnectable) throws -> Future<Int> {

        let goal = Double(session.numberOfTaskGoal)

        return try session.assignedTasks
            .pivots(on: conn)
            .filter(\.isCompleted == true)
            .count()
            .map { (numberOfCompletedTasks) in
                Int((Double(numberOfCompletedTasks * 100) / goal).rounded())
        }
    }

    public static func getCurrentTaskIndex(for sessionId: PracticeSession.ID, on conn: DatabaseConnectable) throws -> Future<Int> {
        
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

    public static func getResult(for session: PracticeSession, on conn: DatabaseConnectable) throws -> Future<[PSTaskResult]> {

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

    public static func getAllSessions(by user: User, on conn: DatabaseConnectable) throws -> Future<[PracticeSession]> {
        return try PracticeSession
            .query(on: conn)
            .filter(\.userID == user.requireID())
            .filter(\.endedAt != nil)
            .sort(\.createdAt, .descending)
            .all()
    }

    public static func getAllSessionsWithSubject(by user: User, on conn: PostgreSQLConnection) throws -> EventLoopFuture<PracticeSession.HistoryList> {
        return try conn.select()
            .all(table: PracticeSession.self)
            .all(table: Subject.self)
            .from(PracticeSession.self)
            .join(\PracticeSession.id, to: \PracticeSession.Pivot.Subtopic.sessionID)
            .join(\PracticeSession.Pivot.Subtopic.subtopicID, to: \Subtopic.id)
            .join(\Subtopic.topicId, to: \Topic.id)
            .join(\Topic.subjectId, to: \Subject.id)
            .where(\PracticeSession.endedAt != nil)
            .where(\PracticeSession.userID == user.requireID())
            .orderBy(\PracticeSession.createdAt, .descending)
            .groupBy(\PracticeSession.id)
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
//        return try PracticeSession
//            .query(on: conn)
//            .filter(\.userID == user.requireID())
//            .join(\PracticeSession.Pivot.Subtopic.sessionID, to: \PracticeSession.id)
//            .join(\Subtopic.id, to: \PracticeSession.Pivot.Subtopic.subtopicID)
//            .join(\Topic.id, to: \Subtopic.topicId)
//            .join(\Subject.id, to: \Topic.subjectId)
//            .filter(\.endedAt != nil)
//            .sort(\.createdAt, .descending)
//            .groupBy(\PracticeSession.id)
//            .alsoDecode(Subject.self)
//            .all()
    }

    static func register<T: Content>(_ submitResult: TaskSubmitResult, result: PracticeSessionResult<T>, in session: PracticeSession, by user: User, on conn: DatabaseConnectable) throws -> Future<TaskResult> {

        return try TaskResultRepository
            .createResult(from: submitResult, by: user, on: conn, in: session)
            .flatMap { result in

//                try WorkPoints.Repository
//                    .create(from: result, by: user, on: conn)
//                    .flatMap { points in

                        try PracticeSession.Repository
                            .markAsComplete(taskID: submitResult.taskID, in: session, on: conn)
                            .catchFlatMap { error in
                                switch error {
                                case PracticeSession.Repository.Errors.noMoreTasks: return conn.future()
                                default: return conn.future(error: error)
                                }
                        }.transform(to: result)
//                }
        }
        
//        guard let taskID = session.currentTaskID else {
//            throw Abort(.internalServerError)
//        }
//        return try PracticeSession.Repository
//            .markAsComplete(taskID: taskID, in: session, on: conn)
//            .flatMap { _ in
//
//                try TaskResultRepository.shared
//                    .createResult(from: submitResult, by: user, on: conn, in: session)
//                    .flatMap { _ in
//
//                        try PracticeSession.Repository
//                            .goalProgress(in: session, on: conn)
//                            .map { progress in
//                                result.progress = Double(progress)
//                                return result
//                        }
//                }
//        }
    }


    public static func cleanSessions(on conn: DatabaseConnectable) -> Future<Void> {

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


    public static func getLatestUnfinnishedSessionPath(for user: User, on conn: DatabaseConnectable) throws -> Future<String?> {

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
    public static func getNumberOfTasks(in session: PracticeSession, on conn: DatabaseConnectable) throws -> Future<Int> {

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
