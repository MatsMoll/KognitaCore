//
//  BookResource.swift
//  KognitaCore
//
//  Created by Mats Mollestad on 03/01/2021.
//

import FluentKit

extension BookResource {
    final class DatabaseModel: Model {

        static var schema: String = "BookResource"

        @DBID(custom: "id", generatedBy: .user)
        var id: Int?

        @Field(key: "startPageNumber")
        var startPageNumber: Int

        @Field(key: "endPageNumber")
        var endPageNumber: Int

        @Field(key: "author")
        var author: String

        @Field(key: "bookTitle")
        var bookTitle: String

        init() {}

        init(id: Resource.ID, data: BookResource.Create.Data) {
            self.id = id
            self.startPageNumber = data.startPageNumber
            self.endPageNumber = data.endPageNumber
            self.author = data.author
            self.bookTitle = data.bookTitle
        }
    }
}

extension BookResource {
    enum Migrations {
        struct Create: Migration {

            func prepare(on database: Database) -> EventLoopFuture<Void> {
                database.schema(BookResource.DatabaseModel.schema)
                    .field("id", .uint, .identifier(auto: false), .references(Resource.DatabaseModel.schema, .id, onDelete: .cascade, onUpdate: .cascade))
                    .field("startPageNumber", .uint, .required)
                    .field("endPageNumber", .uint, .required)
                    .field("author", .string, .required)
                    .field("bookTitle", .string, .required)
                    .create()
            }

            func revert(on database: Database) -> EventLoopFuture<Void> {
                database.schema(BookResource.DatabaseModel.schema)
                    .delete()
            }
        }
    }
}
