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
        return try Repository.goalProgress(for: self, on: conn)
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
    static func create(_ user: User, subtopics: Set<Subtopic.ID>, numberOfTaskGoal: Int, on conn: DatabaseConnectable)
        throws -> Future<PracticeSession> {

        return try Repository.create(
                from: .init(
                    numberOfTaskGoal: numberOfTaskGoal,
                    subtopicsIDs: subtopics,
                    topicIDs: nil
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
        return try Repository
            .assignTask(to: self, on: conn)
    }

    public func getCurrentTaskIndex(_ conn: DatabaseConnectable) throws -> Future<Int> {
        return try Repository
            .getCurrentTaskIndex(for: self.requireID(), on: conn)
    }
    
    public func currentTask(on conn: PostgreSQLConnection) throws -> Future<TaskType> {
        return try Repository
            .currentActiveTask(in: self, on: conn)
    }

    public func taskAt(index: Int, on conn: PostgreSQLConnection) throws -> Future<TaskType> {
        return try Repository
            .taskAt(index: index, in: self, on: conn)
    }
    
    public func pathFor(index: Int) throws -> String {
        return try "/practice-sessions/\(requireID())/tasks/\(index)"
    }
    
    public func submit(_ content: NumberInputTask.Submit.Data, by user: User, with conn: DatabaseConnectable) throws -> Future<PracticeSessionResult<NumberInputTask.Submit.Response>> {
        return try PracticeSession.Repository
            .submitInputTask(content, in: self, by: user, on: conn)
    }
    
    public func submit(_ content: MultipleChoiseTask.Submit, by user: User, with conn: DatabaseConnectable) throws -> Future<PracticeSessionResult<[MultipleChoiseTaskChoise.Result]>> {
        return try PracticeSession.Repository
            .submitMultipleChoise(content, in: self, by: user, on: conn)
    }
    
    public func submit(_ content: FlashCardTask.Submit, by user: User, with conn: DatabaseConnectable) throws -> Future<PracticeSessionResult<FlashCardTask.Submit>> {
        return try PracticeSession.Repository
            .submitFlashCard(content, in: self, by: user, on: conn)
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

extension PracticeSession: Parameter {}
extension PracticeSession: Content {}


public struct TaskType {

    public let task: Task
    public let multipleChoise: MultipleChoiseTask?
    public let numberInputTask: NumberInputTask?

    init(content: (task: Task, chosie: MultipleChoiseTask?, input: NumberInputTask?)) {
        self.task = content.task
        self.multipleChoise = content.chosie
        self.numberInputTask = content.input
    }
}
