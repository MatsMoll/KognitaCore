//
//  TopicPreknowleged.swift
//  KognitaCore
//
//  Created by Mats Mollestad on 29/09/2019.
//

import Vapor
import FluentPostgreSQL

extension Topic {
    struct Pivot {}
}

extension Topic.Pivot {
    /// This modal contains the info of which topics that rely on other topics knowleged.
    /// An example here could  be that Integrals rely on basic calculus
    final class Preknowleged: PostgreSQLPivot {

        public var id: Int?

        public var topicID: Topic.ID
        public var preknowlegedID: Topic.ID

        public var createdAt: Date?

        public typealias Left = Topic
        public typealias Right = Topic

        public static var leftIDKey: LeftIDKey = \.topicID
        public static var rightIDKey: RightIDKey = \.preknowlegedID

        public static var createdAtKey: TimestampKey? = \.createdAt

        init(topicID: Topic.ID, preknowlegedID: Topic.ID) {
            self.topicID = topicID
            self.preknowlegedID = preknowlegedID
        }

        static func create(topic: Topic, requires requieredTopic: Topic, on conn: DatabaseConnectable) throws -> Future<Topic.Pivot.Preknowleged> {
            return try Topic.Pivot.Preknowleged(topicID: topic.requireID(), preknowlegedID: requieredTopic.requireID())
                .create(on: conn)
        }
    }
}

extension Topic.Pivot.Preknowleged: Migration {

    public static func prepare(on conn: PostgreSQLConnection) -> Future<Void> {
        return PostgreSQLDatabase.create(Topic.Pivot.Preknowleged.self, on: conn) { builder in
            try addProperties(to: builder)

            builder.reference(from: \.topicID, to: \Topic.id, onUpdate: .cascade, onDelete: .cascade)
            builder.reference(from: \.preknowlegedID, to: \Topic.id, onUpdate: .cascade, onDelete: .cascade)

            builder.unique(on: \.preknowlegedID, \.topicID)
        }
    }

    public static func revert(on connection: PostgreSQLConnection) -> Future<Void> {
        return PostgreSQLDatabase.delete(Topic.Pivot.Preknowleged.self, on: connection)
    }
}
