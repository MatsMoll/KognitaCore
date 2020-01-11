//
//  PracticeSession.swift
//  App
//
//  Created by Mats Mollestad on 21/01/2019.
//

import FluentPostgreSQL
import FluentSQL
import Vapor

extension Date {
    public var isToday: Bool {
        return Calendar.current.isDateInToday(self)
    }
}

/// A practice session object
public final class PracticeSession: KognitaCRUDModel, SoftDeleatableModel {

    /// The session id
    public var id: Int?

    /// The date the session was ended
    public var endedAt: Date?

    /// The number of task to complete in the session
    public private(set) var numberOfTaskGoal: Int
    
    /// The date when the session was started
    public var createdAt: Date?
    
    public var updatedAt: Date?
    
    public var deletedAt: Date?
    

    init(sessionID: TaskSession.ID, numberOfTaskGoal: Int) throws {
        self.id = sessionID
        guard numberOfTaskGoal > 0 else {
            throw Abort(.badRequest, reason: "Needs more then 0 task goal")
        }
        self.numberOfTaskGoal = numberOfTaskGoal
    }
}

extension PracticeSession {

    func representable(with session: TaskSession) -> PracticeSessionRepresentable {
        TaskSession.PracticeParameter(session: session, practiceSession: self)
    }

    func representable(on conn: DatabaseConnectable) throws -> EventLoopFuture<PracticeSessionRepresentable> {
        let session = self
        return try TaskSession.find(requireID(), on: conn)
            .unwrap(or: Abort(.internalServerError))
            .map { TaskSession.PracticeParameter(session: $0, practiceSession: session) }
    }
    
    func numberOfCompletedTasks(with conn: DatabaseConnectable) throws -> EventLoopFuture<Int> {
        return try assignedTasks
            .pivots(on: conn)
            .filter(\.isCompleted == true)
            .count()
    }

    /// Creates the necessary data for a `PracticeSession`
    ///
    /// - Parameters:
    ///   - user: The user executing the session
    ///   - topics: The topics to practice in the session
    ///   - conn: A transaction connection to the database
    /// - Returns: A `PracticeSession` object
    /// - Throws: If any of the database queries fails
    static func create(_ user: User, subtopics: Set<Subtopic.ID>, numberOfTaskGoal: Int, on conn: DatabaseConnectable)
        throws -> EventLoopFuture<PracticeSession> {

        return try DatabaseRepository.create(
                from: .init(
                    numberOfTaskGoal: numberOfTaskGoal,
                    subtopicsIDs: subtopics,
                    topicIDs: nil
                ),
                by: user,
                on: conn
            )
    }

    public func getCurrentTaskIndex(_ conn: DatabaseConnectable) throws -> EventLoopFuture<Int> {
        return try DatabaseRepository
            .getCurrentTaskIndex(for: self.requireID(), on: conn)
    }
    
    public func currentTask(on conn: PostgreSQLConnection) throws -> EventLoopFuture<TaskType> {
        return try DatabaseRepository
            .currentActiveTask(in: self, on: conn)
    }

    public func taskAt(index: Int, on conn: PostgreSQLConnection) throws -> EventLoopFuture<TaskType> {
        return try DatabaseRepository
            .taskAt(index: index, in: self, on: conn)
    }
    
    public func pathFor(index: Int) throws -> String {
        return try "/practice-sessions/\(requireID())/tasks/\(index)"
    }
}

extension PracticeSession {

    /// The subtopics being practiced
    var subtopics: Siblings<PracticeSession, Subtopic, PracticeSession.Pivot.Subtopic> {
        return siblings()
    }

    /// The assigned tasks in the session
    var assignedTasks: Siblings<PracticeSession, Task, PracticeSession.Pivot.Task> {
        return siblings()
    }

    public var timeUsed: TimeInterval? {
        guard let createdAt = createdAt,
            let endedAt = endedAt else {
             return nil
        }
        return endedAt.timeIntervalSince(createdAt)
    }
}

extension PracticeSession: Content {}


public struct TaskType: Content {

    public let task: Task
    public let multipleChoise: MultipleChoiseTask?

    init(content: (task: Task, chosie: MultipleChoiseTask?)) {
        self.task = content.task
        self.multipleChoise = content.chosie
    }
}

extension PracticeSession {
    public struct CurrentTask: Content {

        public let session: PracticeSession
        public let task: TaskType
        public let index: Int
        public let user: User.Response

        public init(session: PracticeSession, task: TaskType, index: Int, user: User.Response) {
            self.session = session
            self.task = task
            self.index = index
            self.user = user
        }
    }
}
