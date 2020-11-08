//
//  Exam+TaskPivot.swift
//  KognitaCore
//
//  Created by Mats Mollestad on 06/11/2020.
//

import FluentKit

extension TaskSession {
    enum Pivot {}
}

extension TaskSession.Pivot {

    /// A more general TaskSession<->Task reference.
    /// NB: Currently not used with PracticeSession
    final class Task: Model {

        static var schema: String = "TaskSession_Task"

        @DBID(custom: "id")
        public var id: Int?

        @Parent(key: "sessionID")
        var session: PracticeSession.DatabaseModel

        @Parent(key: "taskID")
        var task: TaskDatabaseModel

        @Timestamp(key: "createdAt", on: .create)
        public var createdAt: Date?

        @Timestamp(key: "updatedAt", on: .update)
        public var updatedAt: Date?

        @Field(key: "isCompleted")
        var isCompleted: Bool

        /// The index of the task
        /// The first exicuted task will be 1, then 2, and so on
        @Field(key: "index")
        var index: Int

        init(sessionID: PracticeSession.ID, taskID: KognitaModels.Task.ID, index: Int) {
            self.$session.id = sessionID
            self.$task.id = taskID
            self.index = index
            self.isCompleted = false
        }

        init() {}
    }
}

extension TaskSession.Pivot.Task {
    enum Migrations {
        struct Create: KognitaModelMigration {
            typealias Model = TaskSession.Pivot.Task

            func build(schema: SchemaBuilder) -> SchemaBuilder {
                schema.field("isCompleted", .bool, .required)
                    .field("index", .int, .required)
                    .field("score", .double)
                    .field("sessionID", .uint, .required, .references(TaskSession.schema, .id, onDelete: .cascade, onUpdate: .cascade))
                    .field("taskID", .uint, .required, .references(TaskDatabaseModel.schema, .id, onDelete: .cascade, onUpdate: .cascade))
                    .unique(on: "taskID", "sessionID")
                    .defaultTimestamps()
            }
        }
    }
}
