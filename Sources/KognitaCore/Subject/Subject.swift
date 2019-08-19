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

    /// A description of the topic
    public private(set) var description: String

    /// The name of the subject
    public private(set) var name: String

    /// The creator of the subject
    public private(set) var creatorId: User.ID

    /// The category describing the subject etc. Tech
    public var category: String

    /// The bootstrap color class
    public var colorClass: String

    /// Creation data
    public var createdAt: Date?

    /// Update date
    public var updatedAt: Date?

    public static var createdAtKey: TimestampKey? = \.createdAt
    public static var updatedAtKey: TimestampKey? = \.updatedAt

    init(name: String, category: String, colorClass: String, description: String, creatorId: User.ID) throws {
        self.colorClass = colorClass
        self.category = category
        self.name = name
        self.creatorId = creatorId
        self.description = description

        try self.validateSubject()
    }

    init(content: CreateSubjectRequest, creator: User) throws {
        self.creatorId = try creator.requireID()
        self.name = content.name
        self.description = content.description
        self.category = content.category
        self.colorClass = content.colorClass

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
        colorClass = content.colorClass
        name = content.name
        category = content.category
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
            try addProperties(to: builder)
            builder.reference(from: \.creatorId, to: \User.id, onUpdate: .cascade, onDelete: .cascade)
        }
    }

    public static func revert(on connection: PostgreSQLConnection) -> Future<Void> {
        return PostgreSQLDatabase.delete(Subject.self, on: connection)
    }
}

extension Subject: Content { }

extension Subject: Parameter { }
