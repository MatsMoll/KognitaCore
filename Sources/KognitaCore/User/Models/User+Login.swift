//
//  User+Login.swift
//  KognitaCore
//
//  Created by Mats Mollestad on 27/09/2020.
//

import Foundation
import Fluent

extension User.Login {

    /// A model logging a users loggins
    final class Log: KognitaPersistenceModel {

        static var tableName: String = "UserLoginLog"

        @ID(key: .id)
        var id: UUID?

        @Timestamp(key: "createdAt", on: .create)
        var createdAt: Date?

        @Timestamp(key: "updatedAt", on: .update)
        var updatedAt: Date?

        @Parent(key: "userID")
        var user: User.DatabaseModel

        @Field(key: "ipAddress")
        var ipAddress: String?

        init() {}

        init(userID: User.ID, ipAddress: String?) {
            self.$user.id = userID
            self.ipAddress = ipAddress
        }
    }
}

extension User.Login.Log {

    struct Create: Migration {

        var name: String = "UserLoginLogCreate"

        var schema: String { User.Login.Log.schema }

        func prepare(on database: Database) -> EventLoopFuture<Void> {
            database.schema(schema)
                .id()
                .field("userID", .int, .required, .references(User.DatabaseModel.schema, .id))
                .field("ipAddress", .string)
                .defaultTimestamps()
                .create()
        }

        func revert(on database: Database) -> EventLoopFuture<Void> {
            database.schema(schema).delete()
        }
    }
}
