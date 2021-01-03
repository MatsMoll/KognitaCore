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
        var id: Int?

        /// A description of the topic
        @Field(key: "description")
        var description: String

        @Field(key: "code")
        var code: String

        /// The name of the subject
        @Field(key: "name")
        var name: String

        /// The creator of the subject
        @Parent(key: "creatorID")
        var creator: User.DatabaseModel

        /// The category describing the subject etc. Tech
        @Field(key: "category")
        var category: String

        /// Creation data
        @Timestamp(key: "createdAt", on: .create)
        var createdAt: Date?

        /// Update date
        @Timestamp(key: "updatedAt", on: .update)
        var updatedAt: Date?

        @Children(for: \.$subject)
        var activeSubjects: [User.ActiveSubject]

        @Children(for: \.$subject)
        var topics: [Topic.DatabaseModel]

        init() {}

        init(code: String, name: String, category: String, description: String, creatorId: User.ID) {
            self.code = code
            self.category = category
            self.name = name
            self.$creator.id = creatorId
            self.description = description
        }

        init(content: Create.Data, creator: User) {
            self.code = content.code
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
            self.code           = content.code

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
                .field("code", .string, .required, .sql(.unique))
                .field("description", .string, .required)
                .field("name", .string, .required)
                .field("category", .string, .required)
                .field("creatorID", .uint, .references(User.DatabaseModel.schema, .id, onDelete: .setDefault, onUpdate: .cascade), .sql(.default(1)))
                .defaultTimestamps()
                .create()
        }

        func revert(on database: Database) -> EventLoopFuture<Void> {
            database.schema(schema).delete()
        }
    }

    struct CodeAttribute: Migration {

        func prepare(on database: Database) -> EventLoopFuture<Void> {
            database.schema(Subject.DatabaseModel.schema)
                .field("code", .string, .required, .sql(.default("Unknown")))
                .update()
                .flatMap {
                    Subject.DatabaseModel.query(on: database)
                        .all()
                }.flatMap { subjects in
                    for subject in subjects {
                        let seperatedName = subject.name.split(separator: ":")
                        if
                            seperatedName.count == 2,
                            let code = seperatedName.first,
                            let name = seperatedName.last
                        {
                            subject.code = code.filter { !$0.isWhitespace }
                            subject.name = String(name.drop(while: { $0.isWhitespace }))
                        } else {
                            subject.code = subject.name
                        }
                    }
                    return subjects.map { $0.save(on: database) }
                        .flatten(on: database.eventLoop)
                }.flatMap {
                    database.schema(Subject.DatabaseModel.schema)
                        .constraint(.constraint(.unique(fields: [.key("code")]), name: "Subject.code:unique"))
                        .update()
                }
        }

        func revert(on database: Database) -> EventLoopFuture<Void> {
            Subject.DatabaseModel.query(on: database)
                .all()
                .flatMap { subjects in
                    subjects.forEach { subject in
                        subject.name = "\(subject.code): \(subject.name)"
                    }
                    return subjects.map { $0.save(on: database) }
                        .flatten(on: database.eventLoop)
                }.flatMap {
                    database.schema(Subject.DatabaseModel.schema)
                        .deleteField("code")
                        .update()
                }
        }
    }
}

extension Subject.DatabaseModel: ContentConvertable {
    func content() throws -> Subject {
        try .init(
            id: requireID(),
            code: code,
            name: name,
            description: description,
            category: category
        )
    }
}

extension Subject: Content {}
//extension Subject: ModelParameterRepresentable { }
