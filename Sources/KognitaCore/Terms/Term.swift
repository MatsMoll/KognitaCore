//
//  Term.swift
//  AsyncHTTPClient
//
//  Created by Mats Mollestad on 03/01/2021.
//

import Foundation
import FluentKit

extension Term {
    final class DatabaseModel: Model {

        static let schema: String = "Term"

        @DBID(custom: "id")
        var id: Int?

        @Field(key: "term")
        var term: String

        @Parent(key: "subtopicID")
        var subtopic: Subtopic.DatabaseModel

        /// This may contain Markdown
        @Field(key: "meaning")
        var meaning: String

        @Timestamp(key: "createdAt", on: .create)
        var createdAt: Date?

        @Timestamp(key: "updatedAt", on: .update)
        var updatedAt: Date?

        init() {}

        init(data: Term.Create.Data) {
            self.term = data.term
            self.meaning = data.meaning
            self.$subtopic.id = data.subtopicID
        }
    }
}

extension Term.DatabaseModel: ContentConvertable {
    public func content() throws -> Term {
        try Term(
            id: requireID(),
            term: term,
            meaning: meaning,
            subtopicID: $subtopic.id,
            createdAt: createdAt ?? .now,
            updatedAt: updatedAt ?? .now
        )
    }
}

extension Term {

    enum Migrations {
        struct Create: Migration {

            func prepare(on database: Database) -> EventLoopFuture<Void> {
                database.schema(Term.DatabaseModel.schema)
                    .field("id", .uint, .identifier(auto: true))
                    .field("term", .string, .required)
                    .field("subtopicID", .uint, .required, .references(Subtopic.DatabaseModel.schema, .id, onDelete: .cascade, onUpdate: .cascade))
                    .field("meaning", .string, .required)
                    .defaultTimestamps()
                    .unique(on: "subtopicID", "term")
                    .create()
            }

            func revert(on database: Database) -> EventLoopFuture<Void> {
                database.schema(Term.DatabaseModel.schema)
                    .delete()
            }
        }
    }
}
