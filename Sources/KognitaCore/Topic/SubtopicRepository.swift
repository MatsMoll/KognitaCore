//
//  SubtopicRepository.swift
//  KognitaCore
//
//  Created by Mats Mollestad on 26/08/2019.
//

import Foundation
import Vapor
import FluentPostgreSQL

extension Subtopic {
    public final class Repository: KognitaRepository, KognitaRepositoryEditable, KognitaRepositoryDeletable {
        
        public typealias Model = Subtopic
    }
}

extension Subtopic.Repository {
    
    public static func create(from content: Subtopic.Create.Data, by user: User?, on conn: DatabaseConnectable) throws -> EventLoopFuture<Subtopic> {
        guard let user = user,
            user.isCreator else { throw Abort(.unauthorized) }
        
        return Subtopic(content: content)
            .save(on: conn)
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
