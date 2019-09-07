//
//  PracticeSessionTaskPivot.swift
//  App
//
//  Created by Mats Mollestad on 21/01/2019.
//

import Vapor
import FluentPostgreSQL

extension PracticeSession.Pivot {
    
    public final class Task: PostgreSQLPivot {
        
        public var id: Int?

        var sessionID: PracticeSession.ID

        var taskID: KognitaCore.Task.ID

        public var createdAt: Date?

        var isCompleted: Bool = false
        
        /// The index of the task
        /// The first exicuted task will be 1, then 2, and so on
        var index: Int

        var score: Double?


        public typealias Left = PracticeSession
        public typealias Right = KognitaCore.Task

        public static var leftIDKey: LeftIDKey = \.sessionID
        public static var rightIDKey: RightIDKey = \.taskID

        public static var createdAtKey: TimestampKey? = \.createdAt


        init(session: PracticeSession, task: KognitaCore.Task, index: Int) throws {
            self.sessionID = try session.requireID()
            self.taskID = try task.requireID()
            self.index = index
        }

        static func create(session: PracticeSession, task: KognitaCore.Task, index: Int, on conn: DatabaseConnectable)
            throws -> Future<PracticeSession.Pivot.Task> {
                
            return try PracticeSession.Pivot.Task(session: session, task: task, index: index)
                .create(on: conn)
        }
    }
}

extension PracticeSession.Pivot.Task: Migration {

    public static func prepare(on conn: PostgreSQLConnection) -> Future<Void> {
        return PostgreSQLDatabase.create(PracticeSession.Pivot.Task.self, on: conn) { builder in
            try addProperties(to: builder)

            builder.reference(from: \.taskID, to: \Task.id, onUpdate: .cascade, onDelete: .cascade)
            builder.reference(from: \.sessionID, to: \PracticeSession.id, onUpdate: .cascade, onDelete: .cascade)

            builder.unique(on: \.sessionID, \.taskID)
        }
    }

    public static func revert(on connection: PostgreSQLConnection) -> Future<Void> {
        return PostgreSQLDatabase.delete(PracticeSession.Pivot.Task.self, on: connection)
    }
}
