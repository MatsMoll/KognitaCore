//
//  PracticeSessionTopicPivot.swift
//  App
//
//  Created by Mats Mollestad on 21/01/2019.
//

import Vapor
import FluentPostgreSQL

extension PracticeSession {
    public enum Pivot {}
}

extension PracticeSession.Pivot {
    public final class Subtopic: PostgreSQLPivot {

        public typealias Database = PostgreSQLDatabase

        public typealias Left = PracticeSession
        public typealias Right = KognitaCore.Subtopic

        public static var leftIDKey: LeftIDKey = \.sessionID
        public static var rightIDKey: RightIDKey = \.subtopicID

        public static var createdAtKey: TimestampKey? = \.createdAt

        public var id: Int?
        public var sessionID: PracticeSession.ID
        public var subtopicID: KognitaCore.Subtopic.ID

        public var createdAt: Date?

        init(subtopicID: KognitaCore.Subtopic.ID, session: PracticeSession) throws {
            self.sessionID = try session.requireID()
            self.subtopicID = subtopicID
        }
    }
}

extension PracticeSession.Pivot.Subtopic {

    func create(on conn: DatabaseConnectable, subtopicID: KognitaCore.Subtopic.ID, session: PracticeSession) throws -> Future<PracticeSession.Pivot.Subtopic> {
        return try PracticeSession.Pivot.Subtopic(subtopicID: subtopicID, session: session)
            .create(on: conn)
    }
}

extension PracticeSession.Pivot.Subtopic: Migration {

    public static func prepare(on conn: PostgreSQLConnection) -> EventLoopFuture<Void> {
        return PostgreSQLDatabase.create(PracticeSession.Pivot.Subtopic.self, on: conn) { builder in
            try addProperties(to: builder)
            builder.unique(on: \.sessionID, \.subtopicID)

            builder.reference(from: \.subtopicID, to: \Subtopic.id, onUpdate: .cascade, onDelete: .cascade)
            builder.reference(from: \.sessionID, to: \PracticeSession.id, onUpdate: .cascade, onDelete: .cascade)
        }
    }

    public static func revert(on connection: PostgreSQLConnection) -> EventLoopFuture<Void> {
        return PostgreSQLDatabase.delete(PracticeSession.Pivot.Subtopic.self, on: connection)
    }
}
