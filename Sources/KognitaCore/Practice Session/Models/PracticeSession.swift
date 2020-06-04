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
extension PracticeSession {
    final class DatabaseModel: KognitaCRUDModel, SoftDeleatableModel {

        public static var tableName: String = "PracticeSession"

        /// The session id
        public var id: Int?

        /// The date the session was ended
        public var endedAt: Date?

        /// The number of task to complete in the session
        public var numberOfTaskGoal: Int

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
}

extension PracticeSession {
    func representable(on conn: DatabaseConnectable) -> EventLoopFuture<PracticeSession.PracticeParameter> {
        PracticeSession.PracticeParameter.resolveParameter("\(id)", conn: conn)
    }
}

extension PracticeSession.DatabaseModel {

    func representable(with session: TaskSession) -> PracticeSessionRepresentable {
        PracticeSession.PracticeParameter(session: session, practiceSession: self)
    }

    func representable(on conn: DatabaseConnectable) throws -> EventLoopFuture<PracticeSessionRepresentable> {
        let session = self
        return try TaskSession.find(requireID(), on: conn)
            .unwrap(or: Abort(.internalServerError))
            .map { PracticeSession.PracticeParameter(session: $0, practiceSession: session) }
    }

    func numberOfCompletedTasks(with conn: DatabaseConnectable) throws -> EventLoopFuture<Int> {
        return try assignedTasks
            .pivots(on: conn)
            .filter(\.isCompleted == true)
            .count()
    }

//    public func getCurrentTaskIndex(_ conn: DatabaseConnectable) throws -> EventLoopFuture<Int> {
//        return try DatabaseRepository
//            .getCurrentTaskIndex(for: self.requireID(), on: conn)
//    }
//
//    public func currentTask(on conn: PostgreSQLConnection) throws -> EventLoopFuture<TaskType> {
//        return try DatabaseRepository
//            .currentActiveTask(in: self, on: conn)
//    }
//
//    public func taskAt(index: Int, on conn: PostgreSQLConnection) throws -> EventLoopFuture<TaskType> {
//        return try DatabaseRepository
//            .taskAt(index: index, in: requireID(), on: conn)
//    }

    public func pathFor(index: Int) throws -> String {
        return try "/practice-sessions/\(requireID())/tasks/\(index)"
    }
}

extension PracticeSession.DatabaseModel {

    /// The subtopics being practiced
    var subtopics: Siblings<PracticeSession.DatabaseModel, Subtopic.DatabaseModel, PracticeSession.Pivot.Subtopic> {
        return siblings()
    }

    /// The assigned tasks in the session
    var assignedTasks: Siblings<PracticeSession.DatabaseModel, Task, PracticeSession.Pivot.Task> {
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

        public let session: PracticeSession.PracticeParameter
        public let task: TaskType
        public let index: Int
        public let user: User

        public init(session: PracticeSession.PracticeParameter, task: TaskType, index: Int, user: User) {
            self.session = session
            self.task = task
            self.index = index
            self.user = user
        }
    }
}
