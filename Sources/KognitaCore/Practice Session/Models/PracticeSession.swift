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
public final class PracticeSession: PostgreSQLModel {

    public static var createdAtKey: TimestampKey? = \.createdAt

    /// The session id
    public var id: Int?

    /// The date when the session was started
    public var createdAt: Date?

    /// The date the session was ended
    public var endedAt: Date?

    /// The number of task to complete in the session
    public private(set) var numberOfTaskGoal: Int

    /// The current task if any
    private(set) var currentTaskID: Task.ID?

    /// The next task if it exists
    private(set) var nextTaskID: Task.ID?

    /// The user owning the session
    public let userID: User.ID

    init(user: User, numberOfTaskGoal: Int) throws {
        self.userID = try user.requireID()
        guard numberOfTaskGoal > 0 else {
            throw Abort(.badRequest, reason: "Need more then 0 in task goal")
        }
        self.numberOfTaskGoal = numberOfTaskGoal
    }

}

extension PracticeSession {

    /// Calculates the progress for the current session
    ///
    /// - Parameter conn: A database connection
    /// - Returns: The progress in prosentage able to go above 100% ([0, ∞>)
    /// - Throws: Database error
    func goalProgress(on conn: DatabaseConnectable) throws -> Future<Int> {

        let goal = Double(numberOfTaskGoal)

        return try numberOfCompletedTasks(with: conn)
            .map { (numberOfCompletedTasks) in
                Int((Double(numberOfCompletedTasks * 100) / goal).rounded())
        }
    }
    
    func numberOfCompletedTasks(with conn: DatabaseConnectable) throws -> Future<Int> {
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
    static func create(_ user: User, subtopics: [Subtopic.ID], numberOfTaskGoal: Int, on conn: DatabaseConnectable)
        throws -> Future<PracticeSession> {

        return try PracticeSession(user: user, numberOfTaskGoal: numberOfTaskGoal)
            .create(on: conn)
            .flatMap { (session) in
                try subtopics.map {
                    try PracticeSessionTopicPivot(subtopicID: $0, session: session)
                        .create(on: conn)
                }
                    .flatten(on: conn)
                    .transform(to: session)
        }
    }

    /// Assigns a task to the session
    ///
    /// - Parameter conn: A connection to the database
    /// - Returns: An `Int` with the assigned `Task.ID`
    /// - Throws: If there was an error with the database queries
    func assignNextTask(on conn: DatabaseConnectable) throws -> Future<Int?> {
        return try topics.query(on: conn)
            .all()
            .map { topics in try topics.map { try $0.requireID() } }
            .and(result: conn)
            .flatMap(assignTask)
    }

    func assignTask(in subtopicIDs: [Subtopic.ID], on conn: DatabaseConnectable) throws -> Future<Int?> {
        return try assignedTasks
            .query(on: conn)
            .all()
            .flatMap { (completedTasks) in
                Task.query(on: conn)
                    .filter(
                        FilterOperator.make(
                            \Task.id,
                            Database.queryFilterMethodNotInSubset,
                            completedTasks.map { $0.id }
                        )
                    )
                    .filter(\.subtopicId ~~ subtopicIDs)
                    .all()
            }.flatMap { (tasks) in
                conn.databaseConnection(to: .psql)
                    .flatMap { psqlConn in

                        try TaskResultRepository.shared
                            .getAllResults(for: self.userID, filter: \Subtopic.id ~~ subtopicIDs, with: psqlConn, maxRevisitDays: nil)
                            .flatMap { results in

                                self.currentTaskID = self.nextTaskID

                                let completedTasks = Set(results.map { $0.taskID })
                                let hardTasks = results.filter {
                                    ($0.daysUntilRevisit ?? 30) < 6
                                }
                                let uncompletedTasks = tasks.filter { completedTasks.contains($0.id ?? 0) == false }

                                for result in hardTasks {

                                    if result.sessionID != self.id,
                                        let task = tasks.first(where: { $0.id == result.taskID }) {

                                        self.nextTaskID = try task.requireID()
                                        return try PracticeSessionTaskPivot
                                            .create(self, task, on: conn)
                                            .transform(to: task.id)
                                    }
                                }

                                for task in uncompletedTasks {
                                    self.nextTaskID = try task.requireID()
                                    return try PracticeSessionTaskPivot
                                        .create(self, task, on: conn)
                                        .transform(to: task.id)
                                }

                                guard let task = tasks.randomElement() else {
                                    self.nextTaskID = nil
                                    return conn.future()
                                        .transform(to: nil)
                                }
                                self.nextTaskID = try task.requireID()
                                return try PracticeSessionTaskPivot
                                    .create(self, task, on: conn)
                                    .transform(to: task.id)
                        }
                }
            }.flatMap { [self] (taskID: Int?) in
                self.save(on: conn)
                    .transform(to: taskID)
        }
    }

    /// Finds the current task to be presented in a session
    ///
    /// - Parameter conn: The database connection
    /// - Returns: A `RenderTaskPracticing` object
    /// - Throws: Missing a task to present ext.
    func currentMultipleChoiseTask(on conn: DatabaseConnectable) throws -> Future<MultipleChoiseTask> {
        guard let currentID = currentTaskID else {
            throw Abort(.internalServerError, reason: "Unable to find new tasks")
        }
        return MultipleChoiseTask
            .query(on: conn)
            .filter(\.id == currentID)
            .first()
            .unwrap(or: Abort(.internalServerError))
    }

    /// Finds the current task to be presented in a session
    ///
    /// - Parameter conn: The database connection
    /// - Returns: A `RenderTaskPracticing` object
    /// - Throws: Missing a task to present ext.
    func currentInputTask(on conn: DatabaseConnectable) throws -> Future<NumberInputTask> {
        guard let currentID = currentTaskID else {
            throw Abort(.internalServerError, reason: "Unable to find new tasks")
        }
        return NumberInputTask
            .query(on: conn)
            .filter(\.id == currentID)
            .first()
            .unwrap(or: Abort(.internalServerError))
    }

    /// Finds the current task to be presented in a session
    ///
    /// - Parameter conn: The database connection
    /// - Returns: A `RenderTaskPracticing` object
    /// - Throws: Missing a task to present ext.
    func currentFlashCard(on conn: DatabaseConnectable) throws -> Future<FlashCardTask> {
        guard let currentID = currentTaskID else {
            throw Abort(.internalServerError, reason: "Unable to find new tasks")
        }
        return FlashCardTask
            .query(on: conn)
            .filter(\.id == currentID)
            .first()
            .unwrap(or: Abort(.internalServerError))
    }

    public func getCurrentTaskPath(_ conn: DatabaseConnectable) throws -> Future<String> {
        return try PracticeSessionRepository.shared
            .getCurrentTaskPath(for: self, on: conn)
    }

    public func getNextTaskPath(_ conn: DatabaseConnectable) throws -> Future<String?> {
        return try PracticeSessionRepository.shared
            .getNextTaskPath(for: self, on: conn)
    }
}

extension PracticeSession {

    /// The topics being practiced
    var topics: Siblings<PracticeSession, Topic, PracticeSessionTopicPivot> {
        return siblings()
    }

    /// The assigned tasks in the session
    var assignedTasks: Siblings<PracticeSession, Task, PracticeSessionTaskPivot> {
        return siblings()
    }

    /// True if there is no more tasks, after completion
    public var isLastTask: Bool {
        return nextTaskID == nil
    }

    public var hasAssignedTask: Bool {
        return currentTaskID != nil
    }

    public var timeUsed: TimeInterval? {
        guard let createdAt = createdAt,
            let endedAt = endedAt else {
             return nil
        }
        return endedAt.timeIntervalSince(createdAt)
    }
}

/// Allows `PracticeSession` to be used as a Fluent migration.
extension PracticeSession: Migration {
    /// See `Migration`.
    public static func prepare(on conn: PostgreSQLConnection) -> Future<Void> {
        return PostgreSQLDatabase.create(PracticeSession.self, on: conn) { builder in
            try addProperties(to: builder)

            builder.reference(from: \.userID, to: \User.id)
            builder.reference(from: \.currentTaskID, to: \Task.id)
            builder.reference(from: \.nextTaskID, to: \Task.id)
        }
    }

    public static func revert(on connection: PostgreSQLConnection) -> Future<Void> {
        return PostgreSQLDatabase.delete(PracticeSession.self, on: connection)
    }
}

extension PracticeSession: Parameter {}
