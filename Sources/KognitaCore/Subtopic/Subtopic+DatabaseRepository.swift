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

                Subtopic.DatabaseModel(content: content)
                    .save(on: self.conn)
                    .map { try $0.content() }
        }
    }

    public func update(model: Subtopic, to data: Subtopic.Update.Data, by user: User) throws -> EventLoopFuture<Subtopic> {
        updateDatabase(Subtopic.DatabaseModel.self, model: model, to: data)
    }

    public func delete(model: Subtopic, by user: User?) throws -> EventLoopFuture<Void> {
        deleteDatabase(Subtopic.DatabaseModel.self, model: model)
    }

    public func find(_ id: Subtopic.ID) -> EventLoopFuture<Subtopic?> {
        findDatabaseModel(Subtopic.DatabaseModel.self, withID: id)
    }

    public func find(_ id: Int, or error: Error) -> EventLoopFuture<Subtopic> {
        findDatabaseModel(Subtopic.DatabaseModel.self, withID: id, or: error)
    }

    public func getSubtopics(in topic: Topic) throws -> EventLoopFuture<[Subtopic]> {
        return Subtopic.DatabaseModel.query(on: conn)
            .filter(\.topicID == topic.id)
            .all()
            .map { try $0.map { try $0.content() }}
    }

    public func subtopics(with topicID: Topic.ID) -> EventLoopFuture<[Subtopic]> {
        return Subtopic.DatabaseModel.query(on: conn)
            .filter(\.topicID == topicID)
            .all()
            .map { try $0.map { try $0.content() }}
    }
}
