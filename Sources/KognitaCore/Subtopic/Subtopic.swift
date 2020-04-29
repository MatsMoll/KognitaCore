//
//  Subtopic.swift
//  KognitaCore
//
//  Created by Mats Mollestad on 26/08/2019.
//

import FluentPostgreSQL
import Vapor

public final class Subtopic: KognitaCRUDModel, KognitaModelUpdatable {

    public var id: Int?

    public var name: String

    public var topicId: Topic.ID

    public var createdAt: Date?

    public var updatedAt: Date?

    init(name: String, topicId: Topic.ID) {
        self.name = name
        self.topicId = topicId
    }

    init(content: Create.Data) {
        self.name = content.name
        self.topicId = content.topicId
    }

    public func updateValues(with content: Create.Data) {
        self.name = content.name
        self.topicId = content.topicId
    }

    public static func addTableConstraints(to builder: SchemaCreator<Subtopic>) {
        builder.reference(from: \.topicId, to: \Topic.id, onUpdate: .cascade, onDelete: .cascade)
    }
}

extension Subtopic: Content { }
extension Subtopic: ModelParameterRepresentable { }

extension Subtopic {

    public enum Create {

        public struct Data: Content {

            public let name: String

            public var topicId: Topic.ID
        }

        public typealias Response = Subtopic
    }

    public typealias Edit = Create
}

extension Subtopic {
    public struct Overview: Content {

        public let id: Int
        public let name: String
        public let topicID: Topic.ID

        init(subtopic: Subtopic) {
            self.id = subtopic.id ?? 0
            self.name = subtopic.name
            self.topicID = subtopic.topicId
        }
    }
}
