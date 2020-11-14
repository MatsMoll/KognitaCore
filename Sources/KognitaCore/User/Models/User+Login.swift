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

        /// The name of the table in the database
        static var tableName: String = "UserLoginLog"

        @ID(key: .id)
        /// A id identifying the log
        var id: UUID?

        @Timestamp(key: "createdAt", on: .create)
        /// When the log was created
        var createdAt: Date?

        @Timestamp(key: "updatedAt", on: .update)
        /// When the log was updated
        var updatedAt: Date?

        @Parent(key: "userID")
        /// The user the log is assosiated with
        var user: User.DatabaseModel

        @Field(key: "ipAddress")
        /// The ip address if it exists
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

        /// The name identifying the migration
        var name: String = "UserLoginLogCreate"

        /// The schema to migrate on
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
