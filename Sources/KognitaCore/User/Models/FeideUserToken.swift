//
//  File.swift
//  
//
//  Created by Mats Mollestad on 20/12/2020.
//

import FluentKit

extension FeideUser {
    final class Token: Model {

        static let schema: String = "FeideUser.Token"

        @DBID(custom: "id", generatedBy: .user)
        var id: User.Login.Token.ID?

        init(id: User.Login.Token.ID) {
            self.id = id
        }

        init() {}
    }
}

extension FeideUser.Token {
    enum Migrations {}
}

extension FeideUser.Token.Migrations {
    struct Create: Migration {

        let schema = FeideUser.Token.schema

        func prepare(on database: Database) -> EventLoopFuture<Void> {
            database.schema(schema)
                .field("id", .uint, .identifier(auto: false), .references(User.Login.Token.DatabaseModel.schema, .id, onDelete: .cascade, onUpdate: .cascade))
                .create()
        }

        func revert(on database: Database) -> EventLoopFuture<Void> {
            database.schema(schema).delete()
        }
    }
}
