//
//  PracticeSessionTaskPivot.swift
//  App
//
//  Created by Mats Mollestad on 21/01/2019.
//

import Vapor
import FluentPostgreSQL

public final class PracticeSessionTaskPivot: PostgreSQLPivot {

    public typealias Left = PracticeSession
    public typealias Right = Task

    public static var leftIDKey: LeftIDKey = \.sessionID
    public static var rightIDKey: RightIDKey = \.taskID

    public static var createdAtKey: TimestampKey? = \.createdAt

    public var id: Int?
    var sessionID: PracticeSession.ID
    var taskID: Task.ID
    public var createdAt: Date?
    var isCompleted: Bool = false
    var score: Double?
    var unforgivingScore: Double?

    init(session: PracticeSession, task: Task) throws {
        self.sessionID = try session.requireID()
        self.taskID = try task.requireID()
    }

    static func create(_ session: PracticeSession, _ task: Task, on conn: DatabaseConnectable)
        throws -> Future<PracticeSessionTaskPivot> {
            
        return try PracticeSessionTaskPivot(session: session, task: task)
            .create(on: conn)
    }
}

extension PracticeSessionTaskPivot: Migration {

    public static func prepare(on conn: PostgreSQLConnection) -> Future<Void> {
        return PostgreSQLDatabase.create(PracticeSessionTaskPivot.self, on: conn) { builder in
            try addProperties(to: builder)

            builder.reference(from: \.taskID, to: \Task.id, onUpdate: .cascade, onDelete: .cascade)
            builder.reference(from: \.sessionID, to: \PracticeSession.id, onUpdate: .cascade, onDelete: .cascade)

            builder.unique(on: \.sessionID, \.taskID)
        }
    }

    public static func revert(on connection: PostgreSQLConnection) -> Future<Void> {
        return PostgreSQLDatabase.delete(PracticeSessionTaskPivot.self, on: connection)
    }
}

//struct PracticeSessionTaskScoreMigration: PostgreSQLMigration {
//
//    static func prepare(on conn: PostgreSQLConnection) -> Future<Void> {
//        return PostgreSQLDatabase.update(PracticeSessionTaskPivot.self, on: conn) { builder in
//            builder.field(for: \.score)
//        }
//    }
//
//    static func revert(on connection: PostgreSQLConnection) -> Future<Void> {
//        return PostgreSQLDatabase.delete(PracticeSessionTaskPivot.self, on: connection)
//    }
//}
//
//
//struct PSTaskPivotUnforgivingScoreMigration: PostgreSQLMigration {
//
//    static func prepare(on conn: PostgreSQLConnection) -> Future<Void> {
//        return PostgreSQLDatabase.update(PracticeSessionTaskPivot.self, on: conn) { builder in
//            builder.field(for: \.unforgivingScore)
//        }
//    }
//
//    static func revert(on conn: PostgreSQLConnection) -> Future<Void> {
//        return PostgreSQLDatabase.update(PracticeSessionTaskPivot.self, on: conn) { builder in
//            builder.deleteField(for: \.unforgivingScore)
//        }
//    }
//}


struct PracticeSessionTaskPivotSessionDeleteRelationMigration: PostgreSQLMigration {
    static func prepare(on conn: PostgreSQLConnection) -> EventLoopFuture<Void> {
        return PostgreSQLDatabase.update(PracticeSessionTaskPivot.self, on: conn) { builder in
            builder.deleteReference(from: \.sessionID, to: \PracticeSession.id)
            builder.deleteReference(from: \.taskID, to: \Task.id)
            builder.reference(from: \.taskID, to: \Task.id, onUpdate: .cascade, onDelete: .cascade)
            builder.reference(from: \.sessionID, to: \PracticeSession.id, onUpdate: .cascade, onDelete: .cascade)
        }
    }

    static func revert(on conn: PostgreSQLConnection) -> EventLoopFuture<Void> {
        return conn.future()
    }
}
