//
//  Subject.swift
//  App
//
//  Created by Mats Mollestad on 06/10/2018.
//

import FluentPostgreSQL
import Vapor

public final class Subject: PostgreSQLModel {

    /// The subject id
    public var id: Int?

    /// The subject code. A unique key
    public private(set) var code: String

    /// A description of the topic
    public private(set) var description: String

    /// The name of the subject
    public private(set) var name: String

    /// A url to a image depicting the subject
    public private(set) var imageURL: String

    /// The creator of the subject
    public private(set) var creatorId: User.ID

    /// Creation data
    public var createdAt: Date?

    /// Update date
    public var updatedAt: Date?

    public static var createdAtKey: TimestampKey? = \.createdAt
    public static var updatedAtKey: TimestampKey? = \.updatedAt

    init(code: String, name: String, imageURL: String, description: String, creatorId: User.ID) throws {
        self.code = code
        self.name = name
        self.imageURL = imageURL
        self.creatorId = creatorId
        self.description = description

        try self.validateSubject()
    }

    init(content: CreateSubjectRequest, creator: User) throws {
        self.creatorId = try creator.requireID()
        self.code = content.code
        self.name = content.name
        self.imageURL = content.imageURL
        self.description = content.description

        try self.validateSubject()
    }

    /// Validates the subjects information
    ///
    /// - Throws:
    ///     If one or more values is invalid
    private func validateSubject() throws {
        guard try name.validateWith(regex: "[A-Za-z0-9 ]+") else {
            throw Abort(.badRequest, reason: "Misformed subject name")
        }
        guard try code.validateWith(regex: "[A-Z]{3,5}[0-9]{4,6}") else {
            throw Abort(.badRequest, reason: "Misformed subject code")
        }
        guard try imageURL.validateWith(regex: "(http(s?):)([/|.|\\w|\\s|-])*\\.(?:jpg|png)") else {
            throw Abort(.badRequest, reason: "Misformed subject image URL")
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
    func updateValues(with content: CreateSubjectRequest) throws {
        code = content.code
        name = content.name
        imageURL = content.imageURL
        description = content.description

        try validateSubject()
    }
}

extension Subject {

    var topics: Children<Subject, Topic> {
        return children(\Topic.subjectId)
    }

    var creator: Parent<Subject, User> {
        return parent(\.creatorId)
    }
}

extension Subject: Migration {
    public static func prepare(on conn: PostgreSQLConnection) -> Future<Void> {
        return PostgreSQLDatabase.create(Subject.self, on: conn) { builder in
            builder.field(for: \.id, isIdentifier: true)
            builder.field(for: \.name)
            builder.field(for: \.code)
            builder.field(for: \.imageURL)
            builder.field(for: \.description)
            builder.field(for: \.creatorId)
            builder.field(for: \.createdAt)
            builder.field(for: \.updatedAt)

            builder.reference(from: \.creatorId, to: \User.id)

            builder.unique(on: \.code)
        }
    }

    public static func revert(on connection: PostgreSQLConnection) -> Future<Void> {
        return PostgreSQLDatabase.delete(Subject.self, on: connection)
    }
}

extension Subject: Content { }

extension Subject: Parameter { }
