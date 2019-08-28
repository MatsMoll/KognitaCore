//
//  PracticeSessionRepository.swift
//  KognitaCore
//
//  Created by Mats Mollestad on 12/04/2019.
//

import FluentPostgreSQL
import Vapor

public class PracticeSessionRepository {

    public enum PracticeSessionError: Error {
        case noAssignedTask
        case nextTaskNotAssigned
        case incorrectTaskType
    }

    public static let shared = PracticeSessionRepository()

    public func create(for user: User, with content: PracticeSessionCreateContent, on conn: DatabaseConnectable) -> Future<PracticeSessionCreateResponse> {

        return conn.transaction(on: .psql) { conn in

            try PracticeSession(user: user, numberOfTaskGoal: content.numberOfTaskGoal)
                .create(on: conn)
                .flatMap { session in

                    try content.topicIDs.map {
                        try PracticeSessionTopicPivot(topicID: $0, session: session)
                            .create(on: conn)
                        }
                        .flatten(on: conn)
                        .flatMap { _ in

                            try session
                                .assignNextTask(on: conn)
                                .flatMap { _ in

                                    try session
                                        .assignNextTask(on: conn)
                                        .flatMap { _ in

                                            try session
                                                .getCurrentTaskPath(conn)
                                                .map { path in
                                                    PracticeSessionCreateResponse(redirectionUrl: path)
                                            }
                                    }
                            }
                    }
                }
        }
    }

    public func submitInputTask(_ submit: NumberInputTaskSubmit, in session: PracticeSession, by user: User, on conn: DatabaseConnectable) throws -> Future<PracticeSessionResult<NumberInputTaskSubmitResponse>> {

        guard try user.requireID() == session.userID else {
            throw Abort(.forbidden)
        }

        return try getCurrent(NumberInputTask.self, for: session, on: conn).flatMap { task in
            let result = NumberInputTaskRepository.shared
                .evaluate(submit, for: task)

            let submitResult = try TaskSubmitResult(
                submit: submit,
                result: result,
                taskID: task.requireID()
            )

            return try PracticeSessionRepository.shared
                .register(submitResult, result: result, in: session, by: user, on: conn)
        }
    }

    public func submitMultipleChoise(_ submit: MultipleChoiseTaskSubmit, in session: PracticeSession, by user: User, on conn: DatabaseConnectable) throws -> Future<PracticeSessionResult<[MultipleChoiseTaskChoiseResult]>> {

        guard try user.requireID() == session.userID else {
            throw Abort(.forbidden)
        }

        return try getCurrent(MultipleChoiseTask.self, for: session, on: conn).flatMap { task in

            try MultipleChoiseTaskRepository.shared
                .evaluate(submit, for: task, on: conn)
                .flatMap { result in

                    let submitResult = try TaskSubmitResult(
                        submit: submit,
                        result: result,
                        taskID: task.requireID()
                    )

                    return try PracticeSessionRepository.shared
                        .register(submitResult, result: result, in: session, by: user, on: conn)
            }
        }
    }

    public func submitFlashCard(
        _ submit: FlashCardTaskSubmit,
        in session: PracticeSession,
        by user: User,
        on conn: DatabaseConnectable
    ) throws -> Future<PracticeSessionResult<FlashCardTaskSubmit>> {

        guard try user.requireID() == session.userID else {
            throw Abort(.forbidden)
        }

        return try getCurrent(FlashCardTask.self, for: session, on: conn)
            .flatMap { task in
                
                try session
                    .numberOfCompletedTasks(with: conn)
                    .flatMap { numberOfCompletedTasks in
                        
                        let score = ScoreEvaluater.shared
                            .compress(score: submit.knowledge, range: 0...4)
                        
                        let result = PracticeSessionResult(
                            result: submit,
                            score: score,
                            progress: 0,
                            numberOfCompletedTasks: numberOfCompletedTasks
                        )
                        
                        let submitResult = try TaskSubmitResult(
                            submit: submit,
                            result: result,
                            taskID: task.requireID()
                        )
                        
                        return try PracticeSessionRepository.shared
                            .register(submitResult, result: result, in: session, by: user, on: conn)
                }
        }
    }

    public func getCurrent<T: PostgreSQLModel>(_ taskType: T.Type, for session: PracticeSession, on conn: DatabaseConnectable) throws -> Future<T> {

        guard let taskID = session.currentTaskID else {
            throw PracticeSessionError.noAssignedTask
        }

        return T.find(taskID, on: conn)
            .unwrap(or: PracticeSessionError.incorrectTaskType)
    }

    func markAsComplete(taskID: Task.ID, in session: PracticeSession, on conn: DatabaseConnectable) throws -> Future<PracticeSessionTaskPivot> {

        return try session.assignedTasks
            .pivots(on: conn)
            .filter(\PracticeSessionTaskPivot.taskID == taskID)
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

    public func getCurrentTaskPath(for session: PracticeSession, on conn: DatabaseConnectable) throws -> Future<String> {

        guard let currentTaskID = session.currentTaskID,
            let sessionID = session.id else {

            throw Abort(.internalServerError)
        }
        return try TaskRepository.shared
            .getTaskTypePath(for: currentTaskID, conn: conn)
            .map { path in
                return "/practice-sessions/\(sessionID)/" + path + "/current"
        }
    }

    public func getNextTaskPath(for session: PracticeSession, on conn: DatabaseConnectable) throws -> Future<String?> {

        guard let nextTaskID = session.nextTaskID,
            let sessionID = session.id else {

            return conn.future(nil)
        }
        return try TaskRepository.shared
            .getTaskTypePath(for: nextTaskID, conn: conn)
            .map { path in
                return "/practice-sessions/\(sessionID)/" + path + "/current"
        }
    }

    public func getResult(for session: PracticeSession, on conn: DatabaseConnectable) throws -> Future<[PSTaskResult]> {

        return try TaskResult.query(on: conn)
            .filter(\TaskResult.sessionID == session.requireID())
            .join(\Task.id, to: \TaskResult.taskID)
            .join(\Topic.id, to: \Task.topicId)
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

    func register<T: Content>(
        _ submitResult: TaskSubmitResult,
        result: PracticeSessionResult<T>,
        in session: PracticeSession,
        by user: User,
        on conn: DatabaseConnectable
    ) throws -> Future<PracticeSessionResult<T>> {


        guard let taskID = session.currentTaskID else {
            throw Abort(.internalServerError)
        }
        return try PracticeSessionRepository.shared
            .markAsComplete(taskID: taskID, in: session, on: conn)
            .flatMap { _ in

                try TaskResultRepository.shared
                    .createResult(from: submitResult, by: user, on: conn, in: session)
                    .flatMap { _ in
                        
                        try PracticeSessionRepository.shared
                            .goalProgress(in: session, on: conn)
                            .flatMap { progress in
                                
                                try session
                                    .numberOfCompletedTasks(with: conn)
                                    .map { numberOfCompletedTasks in
                                        
                                        result.numberOfCompletedTasks = numberOfCompletedTasks
                                        result.progress = Double(progress)
                                        return result
                                }
                        }
                }
        }
    }


    public func cleanSessions(on conn: DatabaseConnectable) -> Future<Void> {

//        let maxSessionLimit = Calendar.current.date(byAdding: .hour, value: -20, to: Date()) ?? Date().addingTimeInterval(-20 * 60 * 60)

        return PracticeSession.query(on: conn)
            .filter(\.endedAt == nil)
//            .filter(\.createdAt < maxSessionLimit)
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
            .filter(\PracticeSession.currentTaskID != nil)
            .sort(\.createdAt, .descending)
            .first()
            .flatMap { session in
                
                if let session = session {
                    return try PracticeSessionRepository.shared
                            .getCurrentTaskPath(for: session, on: conn)
                            .map(to: Optional<String>.self) { $0 }
                } else {
                    return conn.future(nil)
                }

        }
    }

    /// Returns the number of tasks in a session
    ///
    public func getNumberOfTasks(in session: PracticeSession, on conn: DatabaseConnectable) throws -> Future<Int> {

        return try PracticeSessionTopicPivot.query(on: conn)
            .join(\Task.topicId, to: \PracticeSessionTopicPivot.topicID)
            .filter(\PracticeSessionTopicPivot.sessionID == session.requireID())
            .count()
    }
}


/// The content needed to create a session
public class PracticeSessionCreateContent: Decodable {
    
    /// The number of task to complete in a session
    public let numberOfTaskGoal: Int

    /// The topic id's for the tasks to map
    public let topicIDs: [Topic.ID]
    
    init(numberOfTaskGoal: Int, topicIDs: [Topic.ID]) {
        self.numberOfTaskGoal = numberOfTaskGoal
        self.topicIDs = topicIDs
    }
}


/// The response when creating a new session
public struct PracticeSessionCreateResponse: Content {

    /// A redirection to the session
    public let redirectionUrl: String
}
