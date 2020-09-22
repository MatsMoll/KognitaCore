//
//  Topic+testable.swift
//  AppTests
//
//  Created by Mats Mollestad on 09/11/2018.
//

import Vapor
import FluentKit
@testable import KognitaCore

extension Topic {
    public static func create(name: String = "Topic", chapter: Int = 1, creator: User? = nil, subject: Subject? = nil, on app: Application) throws -> Topic {

        let createSubject = try subject ?? Subject.create(creator: creator, on: app)

        return try Topic.create(name: name, chapter: chapter, subjectId: createSubject.id, on: app.db)
    }

    public static func create(name: String = "Topic", chapter: Int = 1, subjectId: Subject.ID, on database: Database) throws -> Topic {

        let topic = try Topic.DatabaseModel(name: name, chapter: chapter, subjectId: subjectId)
        return try topic.save(on: database)
            .flatMapThrowing { try topic.content() }
            .wait()
    }
}
