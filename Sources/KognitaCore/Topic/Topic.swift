//
//  Topic.swift
//  App
//
//  Created by Mats Mollestad on 07/10/2018.
//

import Vapor
import FluentKit

extension Topic {
    final class DatabaseModel: KognitaCRUDModel, KognitaModelUpdatable {

        public static var tableName: String = "Topic"
//
//        public struct Response: Content {
//            public let topic: Topic.Overview
//            public let subtopics: [Subtopic.Overview]
//        }
//
//        public struct Overview: Content {
//            public let id: Int
//            public let subjectID: Subject.ID
//            public let name: String
//            public let chapter: Int
//
//            init(topic: Topic) {
//                self.id = topic.id ?? 0
//                self.subjectID = topic.subjectId
//                self.name = topic.name
//                self.chapter = topic.chapter
//            }
//        }

        @DBID(custom: "id")
        public var id: Int?

        /// The subject the topic is assigned to
        @Parent(key: "subjectID")
        public var subject: Subject.DatabaseModel

        @Children(for: \.$topic)
        var subtopics: [Subtopic.DatabaseModel]

        /// The name of the topic
        @Field(key: "name")
        public var name: String

        /// The chapther number in a subject
        @Field(key: "chapter")
        public private(set) var chapter: Int

        @Timestamp(key: "createdAt", on: .create)
        public var createdAt: Date?

        @Timestamp(key: "updatedAt", on: .update)
        public var updatedAt: Date?

        public init(name: String, chapter: Int, subjectId: Subject.ID) throws {
            self.name           = name
            self.chapter        = chapter
            self.$subject.id    = subjectId
        }

        init(content: Create.Data, creator: User) throws {
            $subject.id = content.subjectID
            name        = content.name
            chapter     = content.chapter
        }

        public func updateValues(with content: Create.Data) throws {
            name        = content.name
            chapter     = content.chapter
        }

        init() {}
    }
}

extension Topic.DatabaseModel: ContentConvertable {
    public func content() throws -> Topic {
        try .init(
            id: requireID(),
            subjectID: $subject.id,
            name: name,
            chapter: chapter
        )
    }
}

extension Topic {
    enum Migrations {}
}

extension Topic.Migrations {
    struct Create: KognitaModelMigration {
        typealias Model = Topic.DatabaseModel

        func build(schema: SchemaBuilder) -> SchemaBuilder {
            schema.field("name", .string, .required)
                .field("chapter", .int, .required)
                .field("subjectID", .uint, .references(Subject.DatabaseModel.schema, .id, onDelete: .cascade, onUpdate: .cascade))
                .unique(on: "chapter", "subjectID")
                .defaultTimestamps()
        }
    }
}

extension Topic.DatabaseModel {

//    var subject: Parent<Topic.DatabaseModel, Subject.DatabaseModel> {
//        return parent(\.subjectId)
//    }

//    func numberOfTasks(_ conn: DatabaseConnectable) throws -> Future<Int> {
//        return try DatabaseRepository
//            .numberOfTasks(in: self, on: conn)
//    }
//
//    func tasks(on conn: DatabaseConnectable) throws -> Future<[Task]> {
//        return try DatabaseRepository
//            .tasks(in: self, on: conn)
//    }
//
//    func subtopics(on conn: DatabaseConnectable) throws -> Future<[Subtopic]> {
//        return try DatabaseRepository
//            .subtopics(in: self, on: conn)
//    }
//
//    func content(on conn: DatabaseConnectable) throws -> Future<Topic.Response> {
//        return try DatabaseRepository
//            .content(for: self, on: conn)
//    }
}

extension Topic: Content { }
//extension Topic: ModelParameterRepresentable { }
