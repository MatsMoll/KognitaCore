//
//  Subtopic+DatabaseRepository.swift
//  KognitaCore
//
//  Created by Mats Mollestad on 23/12/2019.
//

import Vapor
import FluentPostgreSQL

extension Subtopic {
    public final class DatabaseRepository: SubtopicRepositoring {}
}

extension Subtopic.DatabaseRepository {

    public static func create(from content: Subtopic.Create.Data, by user: User?, on conn: DatabaseConnectable) throws -> EventLoopFuture<Subtopic> {
        guard let user = user else { throw Abort(.unauthorized) }

        return try User.DatabaseRepository
            .isModerator(user: user, topicID: content.topicId, on: conn)
            .flatMap {

                Subtopic(content: content)
                    .save(on: conn)
        }
    }

    public static func getSubtopics(in topic: Topic, with conn: DatabaseConnectable) throws -> EventLoopFuture<[Subtopic]> {
        return try Subtopic.query(on: conn)
            .filter(\.topicId == topic.requireID())
            .all()
    }

    public static func subtopics(with topicID: Topic.ID, on conn: DatabaseConnectable) -> EventLoopFuture<[Subtopic]> {
        return Subtopic.query(on: conn)
            .filter(\.topicId == topicID)
            .all()
    }
}
