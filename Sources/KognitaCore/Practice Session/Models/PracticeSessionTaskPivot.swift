//
//  PracticeSessionTaskPivot.swift
//  App
//
//  Created by Mats Mollestad on 21/01/2019.
//

import Vapor
import FluentKit

extension PracticeSession.Pivot {

    final class Task: Model {

        static var schema: String = "PracticeSession_Task"

        @DBID(custom: "id")
        public var id: Int?

        @Parent(key: "sessionID")
        var session: PracticeSession.DatabaseModel

        @Parent(key: "taskID")
        var task: TaskDatabaseModel

        @Timestamp(key: "createdAt", on: .create)
        public var createdAt: Date?

        @Field(key: "isCompleted")
        var isCompleted: Bool

        /// The index of the task
        /// The first exicuted task will be 1, then 2, and so on
        @Field(key: "index")
        var index: Int

        @Field(key: "score")
        var score: Double?

        init(sessionID: PracticeSession.ID, taskID: KognitaContent.Task.ID, index: Int) {
            self.$session.id = sessionID
            self.$task.id = taskID
            self.index = index
            self.isCompleted = false
        }

        init() {}

        static func create(session: PracticeSessionRepresentable, task: KognitaCore.TaskDatabaseModel, index: Int, on database: Database)
            throws -> EventLoopFuture<PracticeSession.Pivot.Task> {

            let pivot = try PracticeSession.Pivot.Task(sessionID: session.requireID(), taskID: task.requireID(), index: index)

            return pivot.create(on: database).transform(to: pivot)
        }

        static func create(session: PracticeSessionRepresentable, taskID: KognitaContent.Task.ID, index: Int, on database: Database)
            throws -> EventLoopFuture<PracticeSession.Pivot.Task> {

            let pivot = try PracticeSession.Pivot.Task(sessionID: session.requireID(), taskID: taskID, index: index)
            return pivot.create(on: database).transform(to: pivot)
        }
    }
}

extension PracticeSession.Pivot.Task {
    enum Migrations {
        struct Create: KognitaModelMigration {
            typealias Model = PracticeSession.Pivot.Task

            func build(schema: SchemaBuilder) -> SchemaBuilder {
                schema.field("isCompleted", .bool, .required)
                    .field("index", .int, .required)
                    .field("score", .double)
                    .field("sessionID", .uint, .required, .references(PracticeSession.DatabaseModel.schema, .id, onDelete: .cascade, onUpdate: .cascade))
                    .field("taskID", .uint, .required, .references(TaskDatabaseModel.schema, .id, onDelete: .cascade, onUpdate: .cascade))
                    .field("createdAt", .date, .required)
            }
        }
    }
}

//extension PracticeSession.Pivot.Task: Migration {
//
//    public static func prepare(on conn: PostgreSQLConnection) -> EventLoopFuture<Void> {
//        return PostgreSQLDatabase.create(PracticeSession.Pivot.Task.self, on: conn) { builder in
//            try addProperties(to: builder)
//
//            builder.reference(from: \.taskID, to: \Task.id, onUpdate: .cascade, onDelete: .cascade)
//            builder.reference(from: \.sessionID, to: \PracticeSession.DatabaseModel.id, onUpdate: .cascade, onDelete: .cascade)
//
//            builder.unique(on: \.sessionID, \.taskID)
//        }
//    }
//
//    public static func revert(on connection: PostgreSQLConnection) -> EventLoopFuture<Void> {
//        return PostgreSQLDatabase.delete(PracticeSession.Pivot.Task.self, on: connection)
//    }
//}
