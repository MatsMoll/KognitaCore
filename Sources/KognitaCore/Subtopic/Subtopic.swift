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

        public var topicID: Topic.ID

        public var createdAt: Date?

        public var updatedAt: Date?

        init(name: String, topicID: Topic.ID) {
            self.name = name
            self.topicID = topicID
        }

        init(content: Create.Data) {
            self.name = content.name
            self.topicID = content.topicId
        }

        public func updateValues(with content: Create.Data) {
            self.name = content.name
            self.topicID = content.topicId
        }

        public static func addTableConstraints(to builder: SchemaCreator<Subtopic.DatabaseModel>) {
            builder.reference(from: \.topicID, to: \Topic.DatabaseModel.id, onUpdate: .cascade, onDelete: .cascade)
        }
    }
}

extension Subtopic.DatabaseModel: ContentConvertable {
    func content() throws -> Subtopic {
        try .init(
            id: requireID(),
            name: name,
            topicID: topicID
        )
    }
}

extension Subtopic: Content { }
//extension Subtopic: ModelParameterRepresentable { }
