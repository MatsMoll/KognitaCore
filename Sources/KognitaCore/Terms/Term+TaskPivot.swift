//
//  Term+TaskPivot.swift
//  
//
//  Created by Mats Mollestad on 08/01/2021.
//

import Vapor
import FluentKit

extension Term {
    final class TaskPivot: Model {

        static let schema: String = "Term_Task"

        @DBID(custom: "id")
        var id: Int?

        @Parent(key: "taskID")
        var task: TaskDatabaseModel

        @Parent(key: "termID")
        var term: Term.DatabaseModel

        @Timestamp(key: "createdAt", on: .create)
        var createdAt: Date?

        @Timestamp(key: "updatedAt", on: .update)
        var updatedAt: Date?

        init() {}

        init(taskID: Task.ID, termID: Term.ID) {
            self.$task.id = taskID
            self.$term.id = termID
        }
    }
}

extension Term.TaskPivot {
    enum Migrations {

        struct Create: Migration {

            func prepare(on database: Database) -> EventLoopFuture<Void> {
                database.schema(Term.TaskPivot.schema)
                    .field("id", .uint, .identifier(auto: true))
                    .field("taskID", .uint, .references(TaskDatabaseModel.schema, .id, onDelete: .cascade, onUpdate: .cascade))
                    .field("termID", .uint, .references(Term.DatabaseModel.schema, .id, onDelete: .cascade, onUpdate: .cascade))
                    .defaultTimestamps()
                    .unique(on: "taskID", "termID")
                    .create()
            }

            func revert(on database: Database) -> EventLoopFuture<Void> {
                database.schema(Term.TaskPivot.schema).delete()
            }
        }
    }
}
