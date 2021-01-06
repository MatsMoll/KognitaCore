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

/// The functionality needed for a practice session repository
public protocol PracticeSessionRepository {
    /// Create a practice session for a given user
    /// - Parameters:
    ///   - content: The config of the practice session
    ///   - user: The user creating the session
    func create(from content: PracticeSession.Create.Data, by user: User) throws -> EventLoopFuture<PracticeSession.Create.Response>

    /// Returns all the practice sessions for a given user
    /// - Parameter user: The user to fetch the session for
    func getSessions(for user: User) throws -> EventLoopFuture<[PracticeSession.Overview]>

    /// Extending the session goal for a given session
    /// - Parameters:
    ///   - session: The session to extend
    ///   - user: The user extending the session
    func extend(session: PracticeSession.ID, for user: User) throws -> EventLoopFuture<Void>

    /// Submitting a answer for a given session
    /// - Parameters:
    ///   - submit: The answer to submit
    ///   - session: The session to submit to
    ///   - user: The user submitting the answer
    func submit(_ submit: MultipleChoiceTask.Submit, in session: PracticeSessionRepresentable, by user: User) throws -> EventLoopFuture<TaskSessionResult<[MultipleChoiceTaskChoice.Result]>>

    /// Submitting a topic typing task for a session
    /// - Parameters:
    ///   - submit: The answer to submit
    ///   - session: The session to submit to
    ///   - user: The user submitting the answer
    func submit(_ submit: TypingTask.Submit, in session: PracticeSessionRepresentable, by user: User) throws -> EventLoopFuture<TaskSessionResult<TypingTask.Submit>>

    /// The current active task for a session
    /// - Parameter session: The session to find the task for
    func currentActiveTask(in session: PracticeSession) throws -> EventLoopFuture<TaskType>

    /// Ending the session for a given user
    /// - Parameters:
    ///   - session: The session to end
    ///   - user: The user wanting to end the session
    func end(_ session: PracticeSessionRepresentable, for user: User) -> EventLoopFuture<PracticeSessionRepresentable>

    /// Ending the session for a given user
    /// - Parameters:
    ///   - sessionID: The session to end
    ///   - user: The user wanting to end the session
    func end(sessionID: PracticeSession.ID, for user: User) -> EventLoopFuture<Void>

    /// Returning the session with a given ID
    /// - Parameter id: The id assosated with the session
    func find(_ id: Int) -> EventLoopFuture<PracticeSessionRepresentable>

    /// Returning the task id in a given session and index
    /// - Parameters:
    ///   - index: The task index in the session
    ///   - sessionID: The session id
    func taskID(index: Int, in sessionID: PracticeSession.ID) -> EventLoopFuture<Task.ID>
    
    func tasksWith(sessionID: PracticeSession.ID) -> EventLoopFuture<[Task.ID]>

    /// Returnting the results for a session id
    /// - Parameter sessionID: The session id
    func getResult(for sessionID: PracticeSession.ID) throws -> EventLoopFuture<[Sessions.TaskResult]>

    /// Returning the task for a given index in a session id
    /// - Parameters:
    ///   - index: The index for in the session
    ///   - sessionID: The sessino id
    func taskAt(index: Int, in sessionID: PracticeSession.ID) throws -> EventLoopFuture<TaskType>

    /// Checking if the session is owned by a user
    /// - Parameters:
    ///   - id: The session id to check
    ///   - userID: The id of the user
    func sessionWith(id: PracticeSession.ID, isOwnedBy userID: User.ID) -> EventLoopFuture<Bool>

    /// Returning the progress in a session
    /// - Parameter sessionID: The session to get the progress for
    func goalProgress(in sessionID: PracticeSession.ID) -> EventLoopFuture<Int>
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
    /// converting a DatabaseModel to the PracticeSession Model
    public var practiceSession: PracticeSession { .init(model: self) }
}
