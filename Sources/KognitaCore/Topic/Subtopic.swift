//
//  Subtopic.swift
//  KognitaCore
//
//  Created by Mats Mollestad on 26/08/2019.
//

import FluentPostgreSQL
import Vapor

public final class Subtopic : PostgreSQLModel {

    public var id: Int?

    public var name: String

    public var topicId: Topic.ID

    public var chapter: Int

    /// Creation data
    public var createdAt: Date?

    /// Update date
    public var updatedAt: Date?

    
    public static var createdAtKey: TimestampKey? = \.createdAt
    public static var updatedAtKey: TimestampKey? = \.updatedAt


    init(name: String, chapter: Int, topicId: Topic.ID) {
        self.name = name
        self.chapter = chapter
        self.topicId = topicId
    }

    init(content: Create.Data) {
        self.name = content.name
        self.chapter = content.chapter
        self.topicId = content.topicId
    }

    func updateValues(with content: Create.Data) {
        self.name = content.name
        self.chapter = content.chapter
        self.topicId = content.topicId
    }
}

extension Subtopic: Migration {
    public static func prepare(on conn: PostgreSQLConnection) -> Future<Void> {
        return PostgreSQLDatabase.create(Subtopic.self, on: conn) { builder in

            try addProperties(to: builder)

            builder.unique(on: \.chapter, \.topicId)

            builder.reference(from: \.topicId, to: \Topic.id, onUpdate: .cascade, onDelete: .cascade)
        }
    }

    public static func revert(on connection: PostgreSQLConnection) -> Future<Void> {
        return PostgreSQLDatabase.delete(Subtopic.self, on: connection)
    }
}

extension Subtopic: Content { }

extension Subtopic: Parameter { }


extension Subtopic {

    public struct Create : Content {
        
        public struct Data : Content {

            public let name: String

            public var topicId: Topic.ID

            public var chapter: Int
        }
    }

    public typealias Edit = Create
}
