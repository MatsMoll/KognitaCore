//
//  File.swift
//  
//
//  Created by Mats Mollestad on 19/12/2020.
//

import FluentKit

final class FeideUser: Model {

    static var schema: String = "FeideUser"

    /// User's unique identifier.
    /// Can be `nil` if the user has not been saved yet.
    @DBID(custom: "id", generatedBy: .user)
    var id: User.ID?

    init() { }

    init(id: User.ID) {
        self.id = id
    }
}

extension FeideUser {
    enum Migrations {
        struct Create: Migration {
            func prepare(on database: Database) -> EventLoopFuture<Void> {
                database.schema(FeideUser.schema)
                    .field("id", .uint, .identifier(auto: false), .references(User.DatabaseModel.schema, .id))
                    .create()
            }

            func revert(on database: Database) -> EventLoopFuture<Void> {
                database.schema(FeideUser.schema).delete()
            }
        }
    }
}
