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

        struct NoteTakingSession: Migration {

            var name: String = "LectureNote.Convert.NoteTakingSession"

            func prepare(on database: Database) -> EventLoopFuture<Void> {

                database.transaction { transaction in
                    LectureNote.DatabaseModel.query(on: transaction)
                        .withDeleted()
                        .join(superclass: TaskDatabaseModel.self, with: LectureNote.DatabaseModel.self)
                        .all(LectureNote.DatabaseModel.self, TaskDatabaseModel.self)
                        .flatMap { notes in
                            notes.group(by: \.0.noteSession)
                                .reduce([]) { (creates, values) in
                                    creates + [
                                        LectureNote.TakingSession.DatabaseModel(userID: values.value.first!.1.$creator.id, id: values.key)
                                                .create(on: transaction)
                                    ]
                                }
                                .flatten(on: database.eventLoop)
                        }
                        .flatMap {
                            transaction.schema(LectureNote.DatabaseModel.schema)
                                .foreignKey("noteSession", references: LectureNote.TakingSession.DatabaseModel.schema, .id, onDelete: .cascade, onUpdate: .cascade)
                                .update()
                        }
                }
            }

            func revert(on database: Database) -> EventLoopFuture<Void> {
                database.eventLoop.future()
            }
        }
    }
}
