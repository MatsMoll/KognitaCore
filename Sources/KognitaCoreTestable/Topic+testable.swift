//
//  Topic+testable.swift
//  AppTests
//
//  Created by Mats Mollestad on 09/11/2018.
//

import Vapor
import FluentPostgreSQL
@testable import KognitaCore

extension Topic {
    public static func create(name: String = "Topic", chapter: Int = 1, creator: User? = nil, subject: Subject? = nil, on conn: PostgreSQLConnection) throws -> Topic {

        let createSubject = try subject ?? Subject.create(creator: creator, on: conn)

        return try Topic.create(name: name, chapter: chapter, subjectId: createSubject.requireID(), on: conn)
    }

    public static func create(name: String = "Topic", chapter: Int = 1, subjectId: Subject.ID, on conn: PostgreSQLConnection) throws -> Topic {

        return try Topic(name: name, chapter: chapter, subjectId: subjectId)
            .save(on: conn)
            .wait()
    }
}
