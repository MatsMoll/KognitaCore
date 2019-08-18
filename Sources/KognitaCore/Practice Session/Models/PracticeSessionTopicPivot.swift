//
//  PracticeSessionTopicPivot.swift
//  App
//
//  Created by Mats Mollestad on 21/01/2019.
//

import Vapor
import FluentPostgreSQL

public final class PracticeSessionTopicPivot: PostgreSQLPivot {

    public typealias Left = PracticeSession
    public typealias Right = Topic

    public static var leftIDKey: LeftIDKey = \.sessionID
    public static var rightIDKey: RightIDKey = \.topicID

    public static var createdAtKey: TimestampKey? = \.createdAt

    public var id: Int?
    var sessionID: PracticeSession.ID
    var topicID: Topic.ID

    public var createdAt: Date?

    init(topicID: Topic.ID, session: PracticeSession) throws {
        self.sessionID = try session.requireID()
        self.topicID = topicID
    }

    func create(on conn: DatabaseConnectable, topicID: Topic.ID, _ session: PracticeSession) throws -> Future<PracticeSessionTopicPivot> {
        return try PracticeSessionTopicPivot(topicID: topicID, session: session)
            .create(on: conn)
    }
}

extension PracticeSessionTopicPivot: Migration {

    public static func prepare(on conn: PostgreSQLConnection) -> Future<Void> {
        return PostgreSQLDatabase.create(PracticeSessionTopicPivot.self, on: conn) { builder in
            try addProperties(to: builder)
            builder.unique(on: \.sessionID, \.topicID)
        }
    }

    public static func revert(on connection: PostgreSQLConnection) -> Future<Void> {
        return PostgreSQLDatabase.delete(PracticeSessionTopicPivot.self, on: connection)
    }
}


struct PracticeSessionTopicPivotSessionDeleteRelationMigration: PostgreSQLMigration {
    static func prepare(on conn: PostgreSQLConnection) -> EventLoopFuture<Void> {
        return PostgreSQLDatabase.update(PracticeSessionTopicPivot.self, on: conn) { builder in
            builder.reference(from: \.sessionID, to: \PracticeSession.id, onUpdate: .cascade, onDelete: .cascade)
        }
    }

    static func revert(on conn: PostgreSQLConnection) -> EventLoopFuture<Void> {
        return conn.future()
    }
}
