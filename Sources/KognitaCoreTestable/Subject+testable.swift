//
//  Subject+testable.swift
//  AppTests
//
//  Created by Mats Mollestad on 09/11/2018.
//

import Vapor
import FluentPostgreSQL
@testable import KognitaCore

extension Subject {
    public static func create(name: String = "Math", category: String = "Tech", creator: User? = nil, on conn: PostgreSQLConnection) throws -> Subject {

        let createCreator = try creator ?? User.create(on: conn)
        return try Subject.create(name: name, category: category, creatorId: createCreator.id, on: conn)
    }

    public static func create(name: String = "Math", category: String = "Tech", description: String = "Some description", creatorId: User.ID, on conn: PostgreSQLConnection) throws -> Subject {

        return try Subject.DatabaseModel(
            name: name,
            category: category,
            description: description,
            creatorId: creatorId
        )
            .save(on: conn)
            .map { try $0.content() }
            .wait()
    }

    public func makeActive(for user: User, canPractice: Bool, on conn: DatabaseConnectable) throws {
        try Subject.DatabaseRepository(conn: conn).mark(active: self, canPractice: canPractice, for: user).wait()
    }

    public func makeInactive(for user: User, on conn: DatabaseConnectable) throws {
        try Subject.DatabaseRepository(conn: conn).mark(inactive: self, for: user).wait()
    }

    public func grantModeratorPrivilege(for userID: User.ID, by moderator: User, on conn: DatabaseConnectable) throws {
        try Subject.DatabaseRepository(conn: conn).grantModeratorPrivilege(for: userID, in: self.id, by: moderator).wait()
    }
}
