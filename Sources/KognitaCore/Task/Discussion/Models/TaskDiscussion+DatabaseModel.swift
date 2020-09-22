//
//  DiscussionTask.swift
//  Core
//
//  Created by Eskild Brobak on 25/02/2020.
//

import Vapor
import Fluent

extension Model {
    public typealias DBID<Value> = IDProperty<Self, Value>
        where Value: Codable
}

extension TaskDiscussion {
    final class DatabaseModel: KognitaCRUDModel {

        init() {}

        static var tableName: String = "TaskDiscussion"

        typealias IDValue = Int

        @DBID(custom: "id")
        var id: Int?

        @Parent(key: "userID")
        var user: User.DatabaseModel

        @Field(key: "description")
        var description: String

        @Parent(key: "taskID")
        var task: TaskDatabaseModel

        @Timestamp(key: "createdAt", on: .create)
        var createdAt: Date?

        @Timestamp(key: "updatedAt", on: .update)
        var updatedAt: Date?

        @Children(for: \.$discussion)
        var responses: [TaskDiscussionResponse.DatabaseModel]

        init(data: Create.Data, userID: User.ID) {
            self.description = data.description
            self.$task.id = data.taskID
            self.$user.id = userID
        }

        func update(with data: Update.Data) {
            description = data.description
        }
    }
}

extension TaskDiscussion.Create: Validatable {
    public static func validations(_ validations: inout Validations) {
        validations.add("description", as: String.self, is: .count(4...))
        validations.add("userID", as: Int.self, is: .range(1...))
        validations.add("taskID", as: Int.self, is: .range(1...))
    }
}

extension TaskDiscussion {
    enum Migrations {}
}

extension TaskDiscussion.Migrations {
    struct Create: Migration {

        let schema = TaskDiscussion.DatabaseModel.schema
        let userSchema = User.DatabaseModel.schema
        let taskSchema = TaskDatabaseModel.schema

        func prepare(on database: Database) -> EventLoopFuture<Void> {
            database.schema(schema)
                .field("id", .uint, .identifier(auto: true))
                .field("userID", .uint, .required, .references(userSchema, .id, onDelete: .cascade, onUpdate: .cascade), .sql(.default(1)))
                .field("description", .string, .required)
                .field("taskID", .uint, .references(taskSchema, .id, onDelete: .cascade, onUpdate: .cascade))
                .defaultTimestamps()
                .create()
        }

        func revert(on database: Database) -> EventLoopFuture<Void> {
            database.schema(schema).delete()
        }
    }
}

//extension TaskDiscussion: ModelParameterRepresentable {}
