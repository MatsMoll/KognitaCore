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
    public static func create(name: String = "Math", category: String = "Tech", colorClass: ColorClass = .primary, creator: User? = nil, on conn: PostgreSQLConnection) throws -> Subject {

        let createCreator = try creator ?? User.create(on: conn)
        return try Subject.create(name: name, category: category, colorClass: colorClass, creatorId: createCreator.requireID(), on: conn)
    }

    public static func create(name: String = "Math", category: String = "Tech", colorClass: ColorClass = .primary, description: String = "Some description", creatorId: User.ID, on conn: PostgreSQLConnection) throws -> Subject {

        return try Subject(
            name: name,
            category: category,
            colorClass: colorClass,
            description: description,
            creatorId: creatorId
        )
            .save(on: conn)
            .wait()
    }

    public func makeActive(for user: User, canPractice: Bool, on conn: DatabaseConnectable) throws {
        try Subject.DatabaseRepository.mark(active: self, canPractice: canPractice, for: user, on: conn).wait()
    }

    public func makeInactive(for user: User, on conn: DatabaseConnectable) throws {
        try Subject.DatabaseRepository.mark(inactive: self, for: user, on: conn).wait()
    }

    public func grantModeratorPrivilege(for userID: User.ID, by moderator: User, on conn: DatabaseConnectable) throws {
        try Subject.DatabaseRepository.grantModeratorPrivilege(for: userID, in: self.requireID(), by: moderator, on: conn).wait()
    }
}
