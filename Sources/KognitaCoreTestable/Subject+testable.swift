//
//  Subject+testable.swift
//  AppTests
//
//  Created by Mats Mollestad on 09/11/2018.
//

import Vapor
import FluentKit
@testable import KognitaCore

extension Subject {

    static var numberOfSubjects: Int = 0

    public static func create(name: String = "Math", category: String = "Tech", creator: User? = nil, on app: Application) throws -> Subject {

        let createCreator = try creator ?? User.create(on: app)
        return try Subject.create(name: name, category: category, creatorId: createCreator.id, on: app.db)
    }

    public static func uniqueCode() -> String {
        numberOfSubjects += 1
        return "TDT\(numberOfSubjects)"
    }

    public static func create(name: String = "Math", category: String = "Tech", description: String = "Some description", creatorId: User.ID, on database: Database) throws -> Subject {

        let subject = Subject.DatabaseModel(
            code: uniqueCode(),
            name: name,
            category: category,
            description: description,
            creatorId: creatorId
        )

        return try subject.save(on: database)
            .flatMapThrowing { try subject.content() }
            .wait()
    }

    public func makeActive(for user: User, canPractice: Bool, on app: Application) throws {
        try TestableRepositories.testable(with: app)
            .subjectRepository
            .mark(active: self.id, canPractice: canPractice, for: user.id).wait()
    }

    public func makeInactive(for user: User, on app: Application) throws {
        try TestableRepositories.testable(with: app)
            .subjectRepository
            .mark(inactive: self, for: user).wait()
    }

    public func grantModeratorPrivilege(for userID: User.ID, by moderator: User, on app: Application) throws {
        try TestableRepositories.testable(with: app)
            .subjectRepository
            .grantModeratorPrivilege(for: userID, in: self.id, by: moderator).wait()
    }
}
