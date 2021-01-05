//
//  Term.swift
//  AsyncHTTPClient
//
//  Created by Mats Mollestad on 03/01/2021.
//

import Foundation
import FluentKit

struct Term: Codable, Identifiable {
    let id: Int
}

extension Term {
    enum Create {
        struct Data: Codable {
            let term: String
            let meaning: String
            let subtopicID: Subtopic.ID
        }
    }
}

//struct Resource: Codable, Identifiable {
//    let id: Int
//}

extension Term {
    final class DatabaseModel: Model {

        static let schema: String = "Term"

        @DBID(custom: "id")
        var id: Int?

        @Field(key: "term")
        var term: String

        @Parent(key: "subtopicID")
        var subtopic: Subtopic.DatabaseModel

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

extension Term {

    enum Migrations {
        struct Create: Migration {

            func prepare(on database: Database) -> EventLoopFuture<Void> {
                database.schema(Term.DatabaseModel.schema)
                    .create()
            }

            func revert(on database: Database) -> EventLoopFuture<Void> {
                database.schema(Term.DatabaseModel.schema)
                    .delete()
            }
        }
    }
}
