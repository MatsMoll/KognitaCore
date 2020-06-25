//
//  DiscussionTaskRespons.swift
//  KognitaCore
//
//  Created by Eskild Brobak on 25/02/2020.
//

import Vapor
import Fluent

extension TaskDiscussionResponse {

    final class DatabaseModel: KognitaPersistenceModel {

        init() {}

        static var tableName: String = "TaskDiscussionResponse"

        @DBID(custom: "id")
        var id: Int?

        @Parent(key: "userID")
        var user: User.DatabaseModel

        @Field(key: "response")
        var response: String

        @Parent(key: "discussionID")
        var discussion: TaskDiscussion.DatabaseModel

        @Timestamp(key: "createdAt", on: .create)
        var createdAt: Date?

        @Timestamp(key: "updatedAt", on: .update)
        var updatedAt: Date?

        init(data: TaskDiscussionResponse.Create.Data, userID: User.ID) throws {
            self.response = try data.response.cleanXSS(whitelist: .basicWithImages())
            self.$discussion.id = data.discussionID
            self.$user.id = userID
        }
    }
}

extension TaskDiscussionResponse: Validatable {
    public static func validations(_ validations: inout Validations) {
        validations.add("response", as: String.self, is: .count(4...))
        validations.add("userID", as: Int.self, is: .range(1...))
        validations.add("discussionID", as: Int.self, is: .range(1...))
    }
}

extension TaskDiscussionResponse {
    enum Migrations {}
}

extension TaskDiscussionResponse.Migrations {
    struct Create: Migration {

        let schema = TaskDiscussionResponse.DatabaseModel.schema
        let userSchema = User.DatabaseModel.schema
        let discussionSchema = TaskDiscussion.DatabaseModel.schema

        func prepare(on database: Database) -> EventLoopFuture<Void> {
            database.schema(schema)
                .field("id", .uint, .identifier(auto: true))
                .field("userID", .uint, .required, .references(userSchema, .id, onDelete: .setDefault, onUpdate: .cascade), .sql(.default(1)))
                .field("discussionID", .uint, .required, .references(discussionSchema, .id, onDelete: .cascade, onUpdate: .cascade))
                .field("response", .string, .required)
                .defaultTimestamps()
                .create()
        }

        func revert(on database: Database) -> EventLoopFuture<Void> {
            database.schema(schema).delete()
        }
    }
}

extension SchemaBuilder {
    func defaultTimestamps() -> Self {
        field("createdAt", .date, .required)
            .field("updatedAt", .date, .required)
    }
}
