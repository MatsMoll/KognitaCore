//
//  Subtopic.swift
//  KognitaCore
//
//  Created by Mats Mollestad on 26/08/2019.
//

import Fluent
import Vapor

extension Subtopic {
    final class DatabaseModel: KognitaCRUDModel, KognitaModelUpdatable {

        public static var tableName: String = "Subtopic"

        @DBID(custom: "id")
        public var id: Int?

        @Field(key: "name")
        public var name: String

        @Parent(key: "topicID")
        public var topic: Topic.DatabaseModel

        @Timestamp(key: "createdAt", on: .create)
        public var createdAt: Date?

        @Timestamp(key: "updatedAt", on: .update)
        public var updatedAt: Date?

        @Children(for: \.$subtopic)
        var tasks: [TaskDatabaseModel]

        init() {}

        init(name: String, topicID: Topic.ID) {
            self.name = name
            self.$topic.id = topicID
        }

        init(content: Create.Data) {
            self.name = content.name
            self.$topic.id = content.topicID
        }

        public func updateValues(with content: Create.Data) {
            self.name = content.name
            self.$topic.id = content.topicID
        }
    }
}

extension Subtopic {
    enum Migrations {}
}

extension Subtopic.Migrations {
    struct Create: Migration {

        let schema = Subtopic.DatabaseModel.schema

        func prepare(on database: Database) -> EventLoopFuture<Void> {
            database.schema(schema)
                .field("id", .uint, .identifier(auto: true))
                .field("name", .string, .required)
                .field("topicID", .uint, .required, .references(Topic.DatabaseModel.schema, .id, onDelete: .cascade, onUpdate: .cascade))
                .defaultTimestamps()
                .create()
        }

        func revert(on database: Database) -> EventLoopFuture<Void> {
            database.schema(schema).delete()
        }
    }
}

extension Subtopic.DatabaseModel: ContentConvertable {
    func content() throws -> Subtopic {
        try .init(
            id: requireID(),
            name: name,
            topicID: $topic.id
        )
    }
}

extension Subtopic: Content { }
//extension Subtopic: ModelParameterRepresentable { }
