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

    /// A topic need or recommended before this
    public var preTopicId: Topic.ID?

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

    init(name: String, description: String, chapter: Int, subjectId: Subject.ID, preTopicId: Topic.ID?, creatorId: User.ID) throws {
        self.name           = name
        self.description    = description
        self.chapter        = chapter
        self.subjectId      = subjectId
        self.preTopicId     = preTopicId
        self.creatorId      = creatorId

        try validateTopic()
    }

    init(content: TopicCreateContent, subject: Subject, creator: User) throws {
        creatorId   = try creator.requireID()
        subjectId   = try subject.requireID()
        name        = content.name
        preTopicId  = content.preTopicId
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
        preTopicId  = content.preTopicId
        description = content.description
        chapter     = content.chapter

        try validateTopic()
    }
}

extension Topic {

    var subject: Parent<Topic, Subject> {
        return parent(\.subjectId)
    }

    var preTopic: Parent<Topic, Topic>? {
        return parent(\.id)
    }

    var creator: Parent<Topic, User> {
        return parent(\.creatorId)
    }

    func numberOfTasks(_ conn: DatabaseConnectable) throws -> Future<Int> {
        return try Task.query(on: conn)
            .filter(\.topicId == requireID())
            .count()
    }

    var tasks: Children<Topic, Task> {
        return children(\.topicId)
    }
}

extension Topic: Migration {
    public static func prepare(on conn: PostgreSQLConnection) -> Future<Void> {
        return PostgreSQLDatabase.create(Topic.self, on: conn) { builder in

            try addProperties(to: builder)

            builder.unique(on: \.chapter, \.subjectId)

            builder.reference(from: \.preTopicId, to: \Topic.id, onUpdate: .cascade, onDelete: .setNull)
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

//final class TopicRemoveCreateDate: PostgreSQLMigration {
//    
//    static func prepare(on conn: PostgreSQLConnection) -> EventLoopFuture<Void> {
//        return PostgreSQLDatabase.update(Topic.self, on: conn) { (builder) in
//            builder.deleteField(for: \.creationDate)
//        }
//    }
//    
//    static func revert(on conn: PostgreSQLConnection) -> EventLoopFuture<Void> {
//        return conn.future()
//    }
//}

public final class TopicCreateContent: Content {

    /// This is needed when creating, but is not when editing
    public let subjectId: Subject.ID

    /// A topic need or recommended before this
    public let preTopicId: Topic.ID?

    /// The name of the topic
    public let name: String

    /// A description of the topic
    public let description: String

    /// The chapther number in a subject
    public let chapter: Int
}
