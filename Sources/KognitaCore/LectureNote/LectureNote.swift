//
//  LectureNote.swift
//  KognitaCore
//
//  Created by Mats Mollestad on 17/09/2020.
//

import Foundation
import Fluent

extension LectureNote {

    final class DatabaseModel: KognitaPersistenceModel {

        static var tableName: String = "LectureNote"

        @DBID(custom: "id", generatedBy: .user)
        var id: Int?

        @Field(key: "noteSession")
        var noteSession: UUID

        @Timestamp(key: "createdAt", on: .create)
        var createdAt: Date?

        @Timestamp(key: "updatedAt", on: .update)
        var updatedAt: Date?

        init() {}

        init(id: IDValue, noteSession: UUID) {
            self.id = id
            self.noteSession = noteSession
        }
    }
}

extension LectureNote {

    enum Migrations {

        struct Create: KognitaModelMigration {

            typealias Model = LectureNote.DatabaseModel

            var subclassSchema: String? = TaskDatabaseModel.schema

            func build(schema: SchemaBuilder) -> SchemaBuilder {
                schema.defaultTimestamps()
                    .field("noteSession", .uuid, .required)
            }
        }

        struct NoteSession: Migration {

            func prepare(on database: Database) -> EventLoopFuture<Void> {
                database.schema(LectureNote.DatabaseModel.schema).field("noteSession", .uuid, .required).update()
            }

            func revert(on database: Database) -> EventLoopFuture<Void> {
                database.eventLoop.future()
            }
        }
    }
}
