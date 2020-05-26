//
//  Subtopic+testable.swift
//  KognitaCoreTests
//
//  Created by Mats Mollestad on 26/08/2019.
//

import Vapor
import FluentPostgreSQL
@testable import KognitaCore

extension Subtopic {
    /// Creates a Subtopic for testing
    /// - Parameters:
    ///   - name: The name of the subtopic
    ///   - topic: The topic the subtopic is connected to
    ///   - conn: The database connection
    /// - Throws: If duplicates
    /// - Returns: The created `Subtopic`
    public static func create(name: String = "Topic", topic: Topic? = nil, on conn: PostgreSQLConnection) throws -> Subtopic {

        let usedTopic = try topic ?? Topic.create(on: conn)

        return try Subtopic.create(name: name, topicId: usedTopic.id, on: conn)
    }

    /// Creates a Subtopic for testing
    /// - Parameters:
    ///   - name: The name of the subtopic
    ///   - topicId: The id of the topic the subtopic is connected to
    ///   - conn: The database connection
    /// - Throws: If duplicates
    /// - Returns: The created `Subtopic`
    public static func create(name: String = "Topic", topicId: Topic.ID, on conn: PostgreSQLConnection) throws -> Subtopic {

        return try Subtopic.DatabaseModel(name: name, topicId: topicId)
            .save(on: conn)
            .map { try $0.content() }
            .wait()
    }
}
