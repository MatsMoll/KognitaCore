//
//  Subtopic+testable.swift
//  KognitaCoreTests
//
//  Created by Mats Mollestad on 26/08/2019.
//

import Vapor
import FluentKit
@testable import KognitaCore

extension Subtopic {
    /// Creates a Subtopic for testing
    /// - Parameters:
    ///   - name: The name of the subtopic
    ///   - topic: The topic the subtopic is connected to
    ///   - conn: The database connection
    /// - Throws: If duplicates
    /// - Returns: The created `Subtopic`
    public static func create(name: String = "Topic", topic: Topic? = nil, on app: Application) throws -> Subtopic {

        let usedTopic = try topic ?? Topic.create(on: app)

        return try Subtopic.create(name: name, topicId: usedTopic.id, on: app.db)
    }

    /// Creates a Subtopic for testing
    /// - Parameters:
    ///   - name: The name of the subtopic
    ///   - topicId: The id of the topic the subtopic is connected to
    ///   - conn: The database connection
    /// - Throws: If duplicates
    /// - Returns: The created `Subtopic`
    public static func create(name: String = "Topic", topicId: Topic.ID, on database: Database) throws -> Subtopic {

        let subtopic = Subtopic.DatabaseModel(name: name, topicID: topicId)

        return try subtopic.save(on: database)
            .flatMapThrowing { try subtopic.content() }
            .wait()
    }
}
