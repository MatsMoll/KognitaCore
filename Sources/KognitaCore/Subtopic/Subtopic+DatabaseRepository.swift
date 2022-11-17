//
//  Subtopic+DatabaseRepository.swift
//  KognitaCore
//
//  Created by Mats Mollestad on 23/12/2019.
//

import Vapor
import FluentKit

extension EventLoopFuture where Value == Bool {
    public func ifFalse(throw error: Error) -> EventLoopFuture<Void> {
        flatMapThrowing {
            if $0 == false { throw error }
        }
    }

    public func ifTrue(throw error: Error) -> EventLoopFuture<Void> {
        flatMapThrowing {
            if $0 { throw error }
        }
    }
}

extension Subtopic {
    public struct DatabaseRepository: SubtopicRepositoring, DatabaseConnectableRepository {

        public let database: Database

        public init(database: Database, userRepository: UserRepository) {
            self.database = database
            self.userRepository = userRepository
        }

        private var userRepository: UserRepository
    }
}

extension Subtopic.DatabaseRepository {

    public func create(from content: Subtopic.Create.Data, by user: User?) throws -> EventLoopFuture<Subtopic> {
        guard let user = user else { throw Abort(.unauthorized) }

        return try userRepository
            .isModerator(user: user, topicID: content.topicID)
            .ifFalse(throw: Abort(.forbidden))
            .flatMap {
                let subtopic = Subtopic.DatabaseModel(content: content)
                return subtopic.save(on: self.database)
                    .flatMapThrowing { try subtopic.content() }
        }
    }

    public func updateModelWith(id: Int, to data: Subtopic.Update.Data, by user: User) throws -> EventLoopFuture<Subtopic> {
        updateDatabase(Subtopic.DatabaseModel.self, modelID: id, to: data)
    }

    public func deleteModelWith(id: Int, by user: User?) throws -> EventLoopFuture<Void> {
        deleteDatabase(Subtopic.DatabaseModel.self, modelID: id)
    }

    public func find(_ id: Subtopic.ID) -> EventLoopFuture<Subtopic?> {
        findDatabaseModel(Subtopic.DatabaseModel.self, withID: id)
    }

    public func find(_ id: Int, or error: Error) -> EventLoopFuture<Subtopic> {
        findDatabaseModel(Subtopic.DatabaseModel.self, withID: id, or: error)
    }

    public func getSubtopics(in topic: Topic) throws -> EventLoopFuture<[Subtopic]> {
        return Subtopic.DatabaseModel.query(on: database)
            .filter(\Subtopic.DatabaseModel.$topic.$id == topic.id)
            .all()
            .flatMapEachThrowing { try $0.content() }
    }

    public func subtopics(with topicID: Topic.ID) -> EventLoopFuture<[Subtopic]> {
        return Subtopic.DatabaseModel.query(on: database)
            .filter(\Subtopic.DatabaseModel.$topic.$id == topicID)
            .all()
            .flatMapEachThrowing { try $0.content() }
    }
}
