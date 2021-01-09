//
//  Resource+TermPivot.swift
//  
//
//  Created by Mats Mollestad on 08/01/2021.
//

import FluentKit
import Foundation

extension Resource {

    final class TermPivot: Model {

        static var schema: String = "ResourceTerm_Pivot"

        @DBID()
        var id: UUID?

        @Parent(key: "resourceID")
        var resource: Resource.DatabaseModel

        @Parent(key: "termID")
        var term: Term.DatabaseModel

        init() {}

        init(resourceID: Resource.ID, termID: Term.ID) {
            self.$resource.id = resourceID
            self.$term.id = termID
        }
    }
}

extension Resource.TermPivot {
    enum Migrations {
        struct Create: Migration {

            func prepare(on database: Database) -> EventLoopFuture<Void> {
                database.schema(Resource.TermPivot.schema)
                    .id()
                    .field("termID", .uint, .required, .references(Term.DatabaseModel.schema, .id, onDelete: .cascade, onUpdate: .cascade))
                    .field("resourceID", .uint, .required, .references(Resource.DatabaseModel.schema, .id, onDelete: .cascade, onUpdate: .cascade))
                    .unique(on: "termID", "resourceID")
                    .create()
            }

            func revert(on database: Database) -> EventLoopFuture<Void> {
                database.schema(Resource.TermPivot.schema)
                    .delete()
            }
        }
    }
}

