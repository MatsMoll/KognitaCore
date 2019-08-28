//
//  Topic.swift
//  App
//
//  Created by Mats Mollestad on 07/10/2018.
//

import FluentPostgreSQL
import Vapor

public final class Topic: PostgreSQLModel {

    public var id: Int?

    /// The subject the topic is assigned to
    public var subjectId: Subject.ID

    /// The name of the topic
    public private(set) var name: String

    /// A description of the topic
    public private(set) var description: String

    /// The chapther number in a subject
    public private(set) var chapter: Int

    /// The id of the creator
    public internal(set) var creatorId: User.ID

    /// Creation data
    public var createdAt: Date?

    /// Update date
    public var updatedAt: Date?

    public static var createdAtKey: TimestampKey? = \.createdAt
    public static var updatedAtKey: TimestampKey? = \.updatedAt


    public struct Response : Content {
        public let topic: Topic
        public let subtopics: [Subtopic]
    }


    public init(name: String, description: String, chapter: Int, subjectId: Subject.ID, creatorId: User.ID) throws {
        self.name           = name
        self.description    = description
        self.chapter        = chapter
        self.subjectId      = subjectId
        self.creatorId      = creatorId

        try validateTopic()
    }

    init(content: TopicCreateContent, subject: Subject, creator: User) throws {
        creatorId   = try creator.requireID()
        subjectId   = try subject.requireID()
        name        = content.name
        description = content.description
        chapter     = content.chapter

        try validateTopic()
    }

    private func validateTopic() throws {
        guard try name.validateWith(regex: "[\\u0028-\\u003B\\u0041-\\u005A\\u0061-\\u007A\\u00B4-\\u00FF\\- ]*") else {
            throw Abort(.badRequest, reason: "Misformed name")
        }
        description.makeHTMLSafe()
    }

    func updateValues(with content: TopicCreateContent) throws {
        name        = content.name
        description = content.description
        chapter     = content.chapter

        try validateTopic()
    }
}

extension Topic {

    var subject: Parent<Topic, Subject> {
        return parent(\.subjectId)
    }

    var creator: Parent<Topic, User> {
        return parent(\.creatorId)
    }

    func numberOfTasks(_ conn: DatabaseConnectable) throws -> Future<Int> {
        return try Task.query(on: conn)
            .join(\Subtopic.id, to: \Task.subtopic)
            .filter(\Subtopic.topicId == requireID())
            .count()
    }

    func tasks(on conn: DatabaseConnectable) throws -> Future<[Task]> {
        return try Task.query(on: conn)
            .join(\Subtopic.id, to: \Task.subtopic)
            .filter(\Subtopic.topicId == requireID())
            .all()
    }

    func subtopics(on conn: DatabaseConnectable) throws -> Future<[Subtopic]> {
        return try SubtopicRepository.shared
            .getSubtopics(in: self, with: conn)
    }

    func content(on conn: DatabaseConnectable) throws -> Future<Topic.Response> {
        let topic = self
        return try subtopics(on: conn)
            .map { subtopics in
                Topic.Response(topic: topic, subtopics: subtopics)
        }
    }
}

extension Topic: Migration {
    public static func prepare(on conn: PostgreSQLConnection) -> Future<Void> {
        return PostgreSQLDatabase.create(Topic.self, on: conn) { builder in

            try addProperties(to: builder)

            builder.unique(on: \.chapter, \.subjectId)

            builder.reference(from: \.subjectId, to: \Subject.id, onUpdate: .cascade, onDelete: .cascade)
            builder.reference(from: \.creatorId, to: \User.id, onUpdate: .cascade, onDelete: .setNull)
        }
    }

    public static func revert(on connection: PostgreSQLConnection) -> Future<Void> {
        return PostgreSQLDatabase.delete(Topic.self, on: connection)
    }
}

extension Topic: Content { }

extension Topic: Parameter { }


public final class TopicCreateContent: Content {

    /// This is needed when creating, but is not when editing
    public let subjectId: Subject.ID

    /// The name of the topic
    public let name: String

    /// A description of the topic
    public let description: String

    /// The chapther number in a subject
    public let chapter: Int
}

extension Subtopic {
    public static let unselected = Subtopic(name: "", chapter: 0, topicId: 0)
}

extension Topic {
    public static let unselected = try! Topic(name: "Velg ...", description: "", chapter: 0, subjectId: 0, creatorId: 0)
}

extension Topic.Response {
    public static let unselected: Topic.Response = Topic.Response(topic: .unselected, subtopics: [.unselected])
}


struct TaskSubtopicMigration: PostgreSQLMigration {

    static func prepare(on conn: PostgreSQLConnection) -> EventLoopFuture<Void> {

        let defaultValueConstraint = PostgreSQLColumnConstraint.default(.literal(0))

        return PostgreSQLDatabase.update(Task.self, on: conn) { builder in
            builder.field(for: \.subtopicId, type: .bigint, defaultValueConstraint)
            builder.deleteReference(from: \Task.topicId, to: \Topic.id)
        }.flatMap { _ in
            Topic.query(on: conn)
                .all()
                .flatMap { topics in
                    try topics.map {
                        try Subtopic(name: "Generelt", chapter: 1, topicId: $0.requireID())
                            .save(on: conn)
                    }
                    .flatten(on: conn)
            }
        }.flatMap { subtopics in

            Task.query(on: conn)
                .all()
                .flatMap { tasks in
                    try tasks.map { task in
                        task.subtopicId = try (subtopics.first(where: { task.topicId == $0.topicId })?.requireID() ?? 0)
                        return task.save(on: conn)
                            .transform(to: ())
                    }
                    .flatten(on: conn)
            }
        }.flatMap {
            PostgreSQLDatabase.update(Task.self, on: conn) { builder in
                builder.reference(from: \Task.subtopicId, to: \Subtopic.id)
                builder.deleteField(for: \Task.topicId)
            }
        }
    }

    static func revert(on conn: PostgreSQLConnection) -> EventLoopFuture<Void> {
        return conn.future()
    }
}
