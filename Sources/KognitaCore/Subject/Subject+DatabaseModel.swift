//
//  Subject.swift
//  App
//
//  Created by Mats Mollestad on 06/10/2018.
//

import Vapor
import FluentKit

extension Subject {

    final class DatabaseModel: KognitaCRUDModel, KognitaModelUpdatable {

        public static var tableName: String = "Subject"

        /// The subject id
        @DBID(custom: "id")
        public var id: Int?

        /// A description of the topic
        @Field(key: "description")
        public private(set) var description: String

        /// The name of the subject
        @Field(key: "name")
        public private(set) var name: String

        /// The creator of the subject
        @Parent(key: "creatorId")
        public var creator: User.DatabaseModel

        /// The category describing the subject etc. Tech
        @Field(key: "category")
        public var category: String

        /// Creation data
        @Timestamp(key: "createdAt", on: .create)
        public var createdAt: Date?

        /// Update date
        @Timestamp(key: "updatedAt", on: .update)
        public var updatedAt: Date?

        @Children(for: \.$subject)
        var activeSubjects: [User.ActiveSubject]

        @Children(for: \.$subject)
        var topics: [Topic.DatabaseModel]

        init() {}

        init(name: String, category: String, description: String, creatorId: User.ID) {
            self.category = category
            self.name = name
            self.$creator.id = creatorId
            self.description = description
        }

        init(content: Create.Data, creator: User) {
            self.$creator.id = creator.id
            self.name = content.name
            self.description = content.description
            self.category = content.category
        }

        /// Validates the subjects information
        ///
        /// - Throws:
        ///     If one or more values is invalid
        private func validateSubject() throws {
            guard try name.validateWith(regex: "[A-Za-z0-9 ]+") else {
                throw Abort(.badRequest, reason: "Misformed subject name")
            }
            description = (try? description.cleanXSS(whitelist: .basicWithImages())) ?? description
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

extension Subject {
    enum Migrations {}
}

extension Subject.Migrations {
    struct Create: Migration {

        let schema = Subject.DatabaseModel.schema

        func prepare(on database: Database) -> EventLoopFuture<Void> {
            database.schema(schema)
                .field("id", .uint, .identifier(auto: true))
                .field("description", .string, .required)
                .field("name", .string, .required)
                .field("category", .string, .required)
                .field("creatorId", .uint, .references(User.DatabaseModel.schema, .id, onDelete: .setDefault, onUpdate: .cascade), .sql(.default(1)))
                .defaultTimestamps()
                .create()
        }

        func revert(on database: Database) -> EventLoopFuture<Void> {
            database.schema(schema).delete()
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

extension Subject: Content {}
//extension Subject: ModelParameterRepresentable { }
