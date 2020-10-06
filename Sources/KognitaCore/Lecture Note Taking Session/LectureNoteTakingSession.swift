//
//  LectureNoteSession.swift
//  KognitaCore
//
//  Created by Mats Mollestad on 28/09/2020.
//

import Foundation
import Fluent

extension LectureNote.TakingSession {
    final class DatabaseModel: Model {

        static var schema: String = "LectureNoteTakingSession"

        @DBID(custom: .id, generatedBy: .user)
        var id: UUID?

        @Parent(key: "userID")
        var user: User.DatabaseModel

        @Timestamp(key: "createdAt", on: .create)
        var createdAt: Date?

        @Timestamp(key: "updatedAt", on: .update)
        var updatedAt: Date?

        init() {}

        init(userID: User.ID, id: UUID = .init()) {
            self.id = id
            self.$user.id = userID
        }
    }
}

extension LectureNote.TakingSession {
    enum Migrations {
        struct Create: Migration {

            let schema = LectureNote.TakingSession.DatabaseModel.schema

            func prepare(on database: Database) -> EventLoopFuture<Void> {
                database.schema(schema)
                    .id()
                    .defaultTimestamps()
                    .field("userID", .int, .required, .references(User.DatabaseModel.schema, .id))
                    .create()
            }

            func revert(on database: Database) -> EventLoopFuture<Void> {
                database.schema(schema).delete()
            }
        }
    }
}
