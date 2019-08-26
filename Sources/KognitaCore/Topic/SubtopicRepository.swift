//
//  SubtopicRepository.swift
//  KognitaCore
//
//  Created by Mats Mollestad on 26/08/2019.
//

import Foundation
import Vapor
import FluentPostgreSQL

public final class SubtopicRepository {

    public static let shared = SubtopicRepository()

    public func create(from content: Subtopic.Create.Data, user: User, with conn: DatabaseConnectable) throws -> Future<Subtopic> {
        guard user.isCreator else {
            throw Abort(.unauthorized)
        }
        return Subtopic(content: content)
            .save(on: conn)
    }

    public func delete(_ subtopic: Subtopic, user: User, with conn: DatabaseConnectable) throws -> Future<Void> {
        guard user.isCreator else {
            throw Abort(.unauthorized)
        }
        return subtopic.delete(on: conn)
    }

    public func edit(_ subtopic: Subtopic, with content: Subtopic.Create.Data, user: User, conn: DatabaseConnectable) throws -> Future<Subtopic> {
        guard user.isCreator else {
           throw Abort(.unauthorized)
        }
        subtopic.updateValues(with: content)
        return subtopic.save(on: conn)
    }

    public func getSubtopics(in topic: Topic, with conn: DatabaseConnectable) throws -> Future<[Subtopic]> {
        return try Subtopic.query(on: conn)
            .filter(\.topicId == topic.requireID())
            .all()
    }
}
