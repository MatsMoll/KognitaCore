//
//  Subtopic.swift
//  KognitaCore
//
//  Created by Mats Mollestad on 26/08/2019.
//

import FluentPostgreSQL
import Vapor

extension Subtopic {
    final class DatabaseModel: KognitaCRUDModel, KognitaModelUpdatable {

        public static var tableName: String = "Subtopic"

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

        public static func addTableConstraints(to builder: SchemaCreator<Subtopic.DatabaseModel>) {
            builder.reference(from: \.topicId, to: \Topic.DatabaseModel.id, onUpdate: .cascade, onDelete: .cascade)
        }
    }
}

extension Subtopic.DatabaseModel: ContentConvertable {
    func content() throws -> Subtopic {
        try .init(
            id: requireID(),
            name: name,
            topicID: topicId
        )
    }
}

extension Subtopic: Content { }
//extension Subtopic: ModelParameterRepresentable { }
