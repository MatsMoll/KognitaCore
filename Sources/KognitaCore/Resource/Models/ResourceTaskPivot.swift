//
//  ResourceTaskPivot.swift
//  KognitaCore
//
//  Created by Mats Mollestad on 03/01/2021.
//

import FluentKit
import Foundation

extension Resource {

    final class TaskPivot: Model {

        static var schema: String = "ResourceTask_Pivot"

        @DBID()
        var id: UUID?

        @Parent(key: "resourceID")
        var resource: Resource.DatabaseModel

        @Parent(key: "taskID")
        var task: TaskDatabaseModel

        init() {}

        init(resourceID: Resource.ID, taskID: Task.ID) {
            self.$resource.id = resourceID
            self.$task.id = taskID
        }
    }
}

extension Resource.TaskPivot {
    enum Migrations {
        struct Create: Migration {

            func prepare(on database: Database) -> EventLoopFuture<Void> {
                database.schema(Resource.TaskPivot.schema)
                    .id()
                    .field("taskID", .uint, .required, .references(TaskDatabaseModel.schema, .id, onDelete: .cascade, onUpdate: .cascade))
                    .field("resourceID", .uint, .required, .references(Resource.DatabaseModel.schema, .id, onDelete: .cascade, onUpdate: .cascade))
                    .unique(on: "taskID", "resourceID")
                    .create()
            }

            func revert(on database: Database) -> EventLoopFuture<Void> {
                database.schema(Resource.TaskPivot.schema)
                    .delete()
            }
        }
    }
}
