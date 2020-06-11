//
//  PracticeSessionTaskPivot.swift
//  App
//
//  Created by Mats Mollestad on 21/01/2019.
//

import Vapor
import FluentPostgreSQL

extension PracticeSession.Pivot {

    final class Task: PostgreSQLPivot {

        static var name: String = "PracticeSession_Task"

        public typealias Database = PostgreSQLDatabase

        public var id: Int?

        var sessionID: PracticeSession.ID

        var taskID: KognitaCore.Task.ID

        public var createdAt: Date?

        var isCompleted: Bool = false

        /// The index of the task
        /// The first exicuted task will be 1, then 2, and so on
        var index: Int

        var score: Double?

        public typealias Left = PracticeSession.DatabaseModel
        public typealias Right = KognitaCore.Task

        public static var leftIDKey: LeftIDKey = \.sessionID
        public static var rightIDKey: RightIDKey = \.taskID

        public static var createdAtKey: TimestampKey? = \.createdAt

        init(sessionID: PracticeSession.ID, taskID: KognitaCore.Task.ID, index: Int) {
            self.sessionID = sessionID
            self.taskID = taskID
            self.index = index
        }

        static func create(session: PracticeSessionRepresentable, task: KognitaCore.Task, index: Int, on conn: DatabaseConnectable)
            throws -> EventLoopFuture<PracticeSession.Pivot.Task> {

            return try PracticeSession.Pivot.Task(sessionID: session.requireID(), taskID: task.requireID(), index: index)
                .create(on: conn)
        }

        static func create(session: PracticeSessionRepresentable, taskID: KognitaCore.Task.ID, index: Int, on conn: DatabaseConnectable)
            throws -> EventLoopFuture<PracticeSession.Pivot.Task> {

            return try PracticeSession.Pivot.Task(sessionID: session.requireID(), taskID: taskID, index: index)
                .create(on: conn)
        }
    }
}

extension PracticeSession.Pivot.Task: Migration {

    public static func prepare(on conn: PostgreSQLConnection) -> EventLoopFuture<Void> {
        return PostgreSQLDatabase.create(PracticeSession.Pivot.Task.self, on: conn) { builder in
            try addProperties(to: builder)

            builder.reference(from: \.taskID, to: \Task.id, onUpdate: .cascade, onDelete: .cascade)
            builder.reference(from: \.sessionID, to: \PracticeSession.DatabaseModel.id, onUpdate: .cascade, onDelete: .cascade)

            builder.unique(on: \.sessionID, \.taskID)
        }
    }

    public static func revert(on connection: PostgreSQLConnection) -> EventLoopFuture<Void> {
        return PostgreSQLDatabase.delete(PracticeSession.Pivot.Task.self, on: connection)
    }
}
