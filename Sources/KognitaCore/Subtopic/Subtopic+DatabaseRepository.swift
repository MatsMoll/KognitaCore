//
//  Subtopic+DatabaseRepository.swift
//  KognitaCore
//
//  Created by Mats Mollestad on 23/12/2019.
//

import Vapor
import FluentPostgreSQL

extension Subtopic {
    public struct DatabaseRepository: SubtopicRepositoring, DatabaseConnectableRepository {

        public let conn: DatabaseConnectable
        private var userRepository: some UserRepository { User.DatabaseRepository(conn: conn) }
    }
}

extension Subtopic.DatabaseRepository {

    public func create(from content: Subtopic.Create.Data, by user: User?) throws -> EventLoopFuture<Subtopic> {
        guard let user = user else { throw Abort(.unauthorized) }

        return try userRepository
            .isModerator(user: user, topicID: content.topicId)
            .flatMap {

                Subtopic(content: content)
                    .save(on: self.conn)
        }
    }

    public func getSubtopics(in topic: Topic) throws -> EventLoopFuture<[Subtopic]> {
        return try Subtopic.query(on: conn)
            .filter(\.topicId == topic.requireID())
            .all()
    }

    public func subtopics(with topicID: Topic.ID) -> EventLoopFuture<[Subtopic]> {
        return Subtopic.query(on: conn)
            .filter(\.topicId == topicID)
            .all()
    }
}
