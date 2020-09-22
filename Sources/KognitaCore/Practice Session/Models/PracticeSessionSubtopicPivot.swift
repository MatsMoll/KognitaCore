//
//  PracticeSessionTopicPivot.swift
//  App
//
//  Created by Mats Mollestad on 21/01/2019.
//

import FluentKit
import Vapor

extension PracticeSession {
    enum Pivot {}
}

extension PracticeSession.Pivot {
    final class Subtopic: Model {

        public static var schema: String = "PracticeSession_Subtopic"

        @DBID(custom: "id")
        public var id: Int?

        @Parent(key: "sessionID")
        public var session: PracticeSession.DatabaseModel

        @Parent(key: "subtopicID")
        public var subtopic: KognitaCore.Subtopic.DatabaseModel

        @Timestamp(key: "createdAt", on: .create)
        public var createdAt: Date?

        init(subtopicID: KognitaCore.Subtopic.ID, session: PracticeSession.DatabaseModel) throws {
            self.$session.id = try session.requireID()
            self.$subtopic.id = subtopicID
        }

        init(subtopicID: KognitaCore.Subtopic.ID, sessionID: PracticeSession.ID) {
            self.$session.id = sessionID
            self.$subtopic.id = subtopicID
        }

        init() {}
    }
}

extension PracticeSession.Pivot.Subtopic {

    func create(on database: Database, subtopicID: KognitaCore.Subtopic.ID, session: PracticeSession.DatabaseModel) throws -> EventLoopFuture<PracticeSession.Pivot.Subtopic> {
        let pivot = try PracticeSession.Pivot.Subtopic(subtopicID: subtopicID, session: session)
        return pivot.create(on: database).transform(to: pivot)
    }
}

extension PracticeSession.Pivot.Subtopic {
    enum Migrations {
        struct Create: KognitaModelMigration {
            typealias Model = PracticeSession.Pivot.Subtopic

            func build(schema: SchemaBuilder) -> SchemaBuilder {
                schema.field("sessionID", .uint, .required, .references(PracticeSession.DatabaseModel.schema, .id, onDelete: .cascade, onUpdate: .cascade))
                    .field("subtopicID", .uint, .required, .references(Subtopic.DatabaseModel.schema, .id, onDelete: .cascade, onUpdate: .cascade))
                    .field("createdAt", .datetime, .required)
                    .unique(on: "sessionID", "subtopicID")
            }
        }
    }
}

//extension PracticeSession.Pivot.Subtopic: Migration {
//
//    public static func prepare(on conn: PostgreSQLConnection) -> EventLoopFuture<Void> {
//        return PostgreSQLDatabase.create(PracticeSession.Pivot.Subtopic.self, on: conn) { builder in
//            try addProperties(to: builder)
//            builder.unique(on: \.sessionID, \.subtopicID)
//
//            builder.reference(from: \.subtopicID, to: \Subtopic.DatabaseModel.id, onUpdate: .cascade, onDelete: .cascade)
//            builder.reference(from: \.sessionID, to: \PracticeSession.DatabaseModel.id, onUpdate: .cascade, onDelete: .cascade)
//        }
//    }
//
//    public static func revert(on connection: PostgreSQLConnection) -> EventLoopFuture<Void> {
//        return PostgreSQLDatabase.delete(PracticeSession.Pivot.Subtopic.self, on: connection)
//    }
//}
