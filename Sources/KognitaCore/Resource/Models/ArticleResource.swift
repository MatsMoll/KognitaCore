//
//  ArticleResource.swift
//  KognitaCore
//
//  Created by Mats Mollestad on 03/01/2021.
//

import FluentKit

extension ArticleResource {
    final class DatabaseModel: Model {

        static var schema: String = "ArticleResource"

        @DBID(custom: "id", generatedBy: .user)
        var id: Int?

        @Field(key: "url")
        var url: String

        @Field(key: "author")
        var author: String

        init() {}

        init(id: Resource.ID, url: String, author: String) {
            self.id = id
            self.url = url
            self.author = author
        }
    }
}

extension ArticleResource {
    enum Migrations {
        struct Create: Migration {

            func prepare(on database: Database) -> EventLoopFuture<Void> {
                database.schema(ArticleResource.DatabaseModel.schema)
                    .field("id", .uint, .identifier(auto: false), .references(Resource.DatabaseModel.schema, .id, onDelete: .cascade, onUpdate: .cascade))
                    .field("url", .string, .required)
                    .field("author", .string, .required)
                    .unique(on: "url")
                    .create()
            }

            func revert(on database: Database) -> EventLoopFuture<Void> {
                database.schema(ArticleResource.DatabaseModel.schema)
                    .delete()
            }
        }
    }
}
