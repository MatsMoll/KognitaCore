//
//  Subject.swift
//  App
//
//  Created by Mats Mollestad on 06/10/2018.
//

import FluentPostgreSQL
import Vapor

extension Subject {

    final class DatabaseModel: KognitaCRUDModel, KognitaModelUpdatable {

        public static var tableName: String = "Subject"

        /// The subject id
        public var id: Int?

        /// A description of the topic
        public private(set) var description: String

        /// The name of the subject
        public private(set) var name: String

        /// The creator of the subject
        public var creatorId: User.ID

        /// The category describing the subject etc. Tech
        public var category: String

        /// Creation data
        public var createdAt: Date?

        /// Update date
        public var updatedAt: Date?

        init(name: String, category: String, description: String, creatorId: User.ID) throws {
            self.category = category
            self.name = name
            self.creatorId = creatorId
            self.description = description

            try self.validateSubject()
        }

        init(content: Create.Data, creator: User) throws {
            self.creatorId = creator.id
            self.name = content.name
            self.description = content.description
            self.category = content.category

            try self.validateSubject()
        }

        public static func prepare(on conn: PostgreSQLConnection) -> EventLoopFuture<Void> {
            PostgreSQLDatabase.create(Subject.DatabaseModel.self, on: conn) { builder in
                try addProperties(to: builder)
                builder.reference(from: \.creatorId, to: \User.DatabaseModel.id, onUpdate: .cascade, onDelete: .setDefault)
            }.flatMap {
                PostgreSQLDatabase.update(Subject.DatabaseModel.self, on: conn) { builder in
                    builder.deleteField(for: \.creatorId)
                    builder.field(for: \.creatorId, type: .int, .default(1))
                }
            }
        }

        /// Validates the subjects information
        ///
        /// - Throws:
        ///     If one or more values is invalid
        private func validateSubject() throws {
            guard try name.validateWith(regex: "[A-Za-z0-9 ]+") else {
                throw Abort(.badRequest, reason: "Misformed subject name")
            }
            description.makeHTMLSafe()
        }

        /// Sets the values on the model
        ///
        /// - Parameter content:
        ///     The new values
        ///
        /// - Throws:
        ///     If invalid values
        public func updateValues(with content: Subject.Create.Data) throws {
            self.name           = content.name
            self.category       = content.category
            self.description    = content.description

            try validateSubject()
        }
    }
}

extension Subject.DatabaseModel: ContentConvertable {
    func content() throws -> Subject {
        try .init(
            id: requireID(),
            name: name,
            description: description,
            category: category
        )
    }
}

extension Subject.DatabaseModel {

    var topics: Children<Subject.DatabaseModel, Topic.DatabaseModel> {
        return children(\Topic.DatabaseModel.subjectId)
    }

    var creator: Parent<Subject.DatabaseModel, User.DatabaseModel> {
        return parent(\.creatorId)
    }
}

extension Subject: Content {}
//extension Subject: ModelParameterRepresentable { }
