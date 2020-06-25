//
//  TaskSolution.swift
//  KognitaCore
//
//  Created by Mats Mollestad on 20/10/2019.
//

import Vapor
import FluentKit

/// One solution to a `Task`
extension TaskSolution {
    final class DatabaseModel: KognitaPersistenceModel {

        public static var tableName: String = "TaskSolution"

        @DBID(custom: "id")
        public var id: Int?

        @Timestamp(key: "createdAt", on: .create)
        public var createdAt: Date?

        @Timestamp(key: "updatedAt", on: .update)
        public var updatedAt: Date?

        @Field(key: "solution")
        public var solution: String

        @Parent(key: "creatorID")
        public var creator: User.DatabaseModel

        @Field(key: "isApproved")
        public var isApproved: Bool

        @OptionalParent(key: "approvedBy")
        public var approvedBy: User.DatabaseModel?

        @Parent(key: "taskID")
        public var task: TaskDatabaseModel

        @Field(key: "presentUser")
        public var presentUser: Bool

        init() {}

        init(data: Create.Data, creatorID: User.ID) throws {
            self.solution = try data.solution.cleanXSS(whitelist: .basicWithImages())
            self.presentUser = data.presentUser
            self.$task.id = data.taskID
            self.$creator.id = creatorID
            self.isApproved = false
            self.$approvedBy.id = nil
//            try validate()
        }

        public func update(with data: TaskSolution.Update.Data) throws {
            if let solution = data.solution {
                self.solution = try solution.cleanXSS(whitelist: .basicWithImages())
            }
            if let presentUser = data.presentUser {
                self.presentUser = presentUser
            }
//            try validate()
        }

        public func approve(by user: User) throws -> TaskSolution.DatabaseModel {
            guard approvedBy == nil else {
                return self
            }
            $approvedBy.id = user.id
            isApproved = true
            return self
        }

//        public static func validations() throws -> Validations<TaskSolution.DatabaseModel> {
//            var validator = Validations(TaskSolution.DatabaseModel.self)
//            try validator.add(\.solution, .count(3...))
//            try validator.add(\.creatorID, .range(1...))
//            try validator.add(\.taskID, .range(1...))
//            return validator
//        }
    }
}

extension TaskSolution {
    enum Migrations {}
}

extension TaskSolution.Migrations {
    struct Create: KognitaModelMigration {

        typealias Model = TaskSolution.DatabaseModel

        func build(schema: SchemaBuilder) -> SchemaBuilder {
            schema.defaultTimestamps()
                .field("solution", .string, .required)
                .field("taskID", .uint, .required, .references(TaskDatabaseModel.schema, .id, onDelete: .cascade, onUpdate: .cascade))
                .field("creatorID", .uint, .required, .sql(.default(1)), .references(User.DatabaseModel.schema, .id, onDelete: .setDefault, onUpdate: .cascade))
                .field("approvedBy", .uint, .sql(.default(1)), .references(User.DatabaseModel.schema, .id, onDelete: .setDefault, onUpdate: .cascade))
                .field("presentUser", .bool, .required)
                .field("isApproved", .bool, .required)
        }
    }
}

extension TaskSolution.DatabaseModel: ContentConvertable {
    func content() throws -> TaskSolution {
        try .init(
            id: requireID(),
            taskID: $task.id,
            createdAt: createdAt ?? .now,
            solution: solution,
            creatorID: $creator.id,
            approvedBy: $approvedBy.id ?? 0
        )
    }
}

protocol KognitaModelMigration: Migration {
    associatedtype Model: FluentKit.Model

    var subclassSchema: String? { get }

    func build(schema: SchemaBuilder) -> SchemaBuilder
}

extension KognitaModelMigration {

    var subclassSchema: String? { nil }

    func prepare(on database: Database) -> EventLoopFuture<Void> {

        if let subclassSchema = subclassSchema {
            return build(schema:
                database.schema(Model.schema)
                    .field("id", .uint, .identifier(auto: true), .references(subclassSchema, .id, onDelete: .cascade, onUpdate: .cascade))
            ).create()
        } else {
            return build(schema:
                database.schema(Model.schema)
                    .field("id", .uint, .identifier(auto: true))
            ).create()
        }
    }

    func revert(on database: Database) -> EventLoopFuture<Void> {
        database.schema(Model.schema).delete()
    }
}
