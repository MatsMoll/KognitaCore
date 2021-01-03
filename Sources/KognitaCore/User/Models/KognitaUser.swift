//
//  File.swift
//  
//
//  Created by Mats Mollestad on 19/12/2020.
//

import FluentKit

final class KognitaUser: Model {

    static var schema: String = "KognitaUser"

    /// User's unique identifier.
    /// Can be `nil` if the user has not been saved yet.
    @DBID(custom: "id", generatedBy: .user)
    public var id: Int?

    /// BCrypt hash of the user's password.
    @Field(key: "passwordHash")
    public var passwordHash: String

    init() {}

    init(id: User.ID, passwordHash: String) {
        self.id = id
        self.passwordHash = passwordHash
    }
}

extension KognitaUser {
    enum Migrations {
        struct Create: Migration {
            func prepare(on database: Database) -> EventLoopFuture<Void> {
                database.schema(KognitaUser.schema)
                    .field("id", .uint, .identifier(auto: false), .references(User.DatabaseModel.schema, .id))
                    .field("passwordHash", .string, .required)
                    .create()
            }

            func revert(on database: Database) -> EventLoopFuture<Void> {
                database.schema(KognitaUser.schema).delete()
            }
        }
    }
}
