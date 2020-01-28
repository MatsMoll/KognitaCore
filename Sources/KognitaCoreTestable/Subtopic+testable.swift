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
    public static func create(name: String = "Topic", topic: Topic? = nil, on conn: PostgreSQLConnection) throws -> Subtopic {

        let usedTopic = try topic ?? Topic.create(on: conn)

        return try Subtopic.create(name: name, topicId: usedTopic.requireID(), on: conn)
    }

    public static func create(name: String = "Topic", topicId: Topic.ID, on conn: PostgreSQLConnection) throws -> Subtopic {

        return try Subtopic(name: name, topicId: topicId)
            .save(on: conn)
            .wait()
    }
}

