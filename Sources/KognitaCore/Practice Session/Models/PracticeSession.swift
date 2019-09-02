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
public final class PracticeSession : KognitaCRUDModel, SoftDeleatableModel {

    /// The session id
    public var id: Int?

    /// The date the session was ended
    public var endedAt: Date?

    /// The number of task to complete in the session
    public private(set) var numberOfTaskGoal: Int

    /// The user owning the session
    public let userID: User.ID
    
    /// The date when the session was started
    public var createdAt: Date?
    
    public var updatedAt: Date?
    
    public var deletedAt: Date?
    

    init(user: User, numberOfTaskGoal: Int) throws {
        self.userID = try user.requireID()
        guard numberOfTaskGoal > 0 else {
            throw Abort(.badRequest, reason: "Need more then 0 in task goal")
        }
        self.numberOfTaskGoal = numberOfTaskGoal
    }

    public static func addTableConstraints(to builder: SchemaCreator<PracticeSession>) {
        builder.reference(from: \.userID, to: \User.id, onUpdate: .cascade, onDelete: .cascade)
    }
}

extension PracticeSession {

    /// Calculates the progress for the current session
    ///
    /// - Parameter conn: A database connection
    /// - Returns: The progress in prosentage able to go above 100% ([0, ∞>)
    /// - Throws: Database error
    func goalProgress(on conn: DatabaseConnectable) throws -> Future<Int> {
        return try Repository.shared
            .goalProgress(in: self, on: conn)
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
        throws -> Future<PracticeSession> {

        return try Repository.shared
            .create(
                from: .init(
                    numberOfTaskGoal: numberOfTaskGoal,
                    subtopicsIDs: subtopics
                ),
                by: user,
                on: conn
            )
    }

    /// Assigns a task to the session
    ///
    /// - Parameter conn: A connection to the database
    /// - Returns: An `Int` with the assigned `Task.ID`
    /// - Throws: If there was an error with the database queries
    func assignNextTask(on conn: DatabaseConnectable) throws -> Future<Void> {
        return try Repository.shared
            .assignTask(to: self, on: conn)
    }

    /// Finds the current task to be presented in a session
    ///
    /// - Parameter conn: The database connection
    /// - Returns: A `RenderTaskPracticing` object
    /// - Throws: Missing a task to present ext.
    func currentMultipleChoiseTask(on conn: DatabaseConnectable) throws -> Future<MultipleChoiseTask> {
        return try Repository.shared
            .currentMultipleChoiseTask(in: self, on: conn)
    }

    /// Finds the current task to be presented in a session
    ///
    /// - Parameter conn: The database connection
    /// - Returns: A `RenderTaskPracticing` object
    /// - Throws: Missing a task to present ext.
    func currentInputTask(on conn: DatabaseConnectable) throws -> Future<NumberInputTask> {
        return try Repository.shared
            .currentInputTask(in: self, on: conn)
    }

    /// Finds the current task to be presented in a session
    ///
    /// - Parameter conn: The database connection
    /// - Returns: A `RenderTaskPracticing` object
    /// - Throws: Missing a task to present ext.
    func currentFlashCard(on conn: DatabaseConnectable) throws -> Future<FlashCardTask> {
        return try Repository.shared
            .currentFlashCard(in: self, on: conn)
    }

    public func getCurrentTaskPath(_ conn: DatabaseConnectable) throws -> Future<String> {
        return try Repository.shared
            .getCurrentTaskPath(for: self, on: conn)
    }

    public func getNextTaskPath(_ conn: DatabaseConnectable) throws -> Future<String?> {
        return try Repository.shared
            .getNextTaskPath(for: self, on: conn)
    }
    
    public func currentTask(_ conn: DatabaseConnectable) throws -> Future<(Task, MultipleChoiseTask?, NumberInputTask?)> {
        conn.databaseConnection(to: .psql)
            .flatMap { psqlConn in
                Repository.shared
                    .currentActiveTask(on: psqlConn)
        }
    }
}

extension PracticeSession {

    /// The topics being practiced
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

extension PracticeSession: Parameter {}
extension PracticeSession: Content {}
