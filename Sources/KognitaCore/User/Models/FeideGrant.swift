//
//  File.swift
//  
//
//  Created by Mats Mollestad on 25/12/2020.
//

import FluentKit
import Foundation

extension Feide.Grant {

    final class DatabaseModel: Model {

        static var schema: String = "Feide.Grant"

        @DBID(custom: "id")
        var id: Int?

        @Field(key: "token")
        var token: String

        @Parent(key: "userID")
        var user: User.DatabaseModel

        @Timestamp(key: "createdAt", on: .create)
        var createdAt: Date?

        @Field(key: "loggedOutAt")
        var loggedOutAt: Date?

        init() {}

        init(grant: Feide.Grant, userID: User.ID) {
            $user.id = userID
            token = grant.code
        }
    }
}

extension Feide.Grant {
    enum Migrations {
        struct Create: Migration {

            func prepare(on database: Database) -> EventLoopFuture<Void> {
                database.schema(Feide.Grant.DatabaseModel.schema)
                    .field("id", .uint, .identifier(auto: true))
                    .field("token", .string, .required)
                    .field("userID", .uint, .required, .references(User.DatabaseModel.schema, .id, onDelete: .cascade, onUpdate: .cascade))
                    .field("createdAt", .datetime)
                    .field("loggedOutAt", .datetime)
                    .create()
            }

            func revert(on database: Database) -> EventLoopFuture<Void> {
                database.schema(Feide.Grant.DatabaseModel.schema).delete()
            }
        }
    }
}
