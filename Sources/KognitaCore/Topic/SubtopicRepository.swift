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
        
        public static let shared = Repository()
    }
}

extension Subtopic.Repository {
    
    public func create(from content: Subtopic.Create.Data, by user: User?, on conn: DatabaseConnectable) throws -> EventLoopFuture<Subtopic> {
        guard let user = user,
            user.isCreator else { throw Abort(.unauthorized) }
        
        return Subtopic(content: content)
            .save(on: conn)
    }
    
    public func getSubtopics(in topic: Topic, with conn: DatabaseConnectable) throws -> Future<[Subtopic]> {
        return try Subtopic.query(on: conn)
            .filter(\.topicId == topic.requireID())
            .all()
    }
    
    public func find(_ subtopicID: Subtopic.ID, on conn: DatabaseConnectable) -> Future<Subtopic?> {
        return Subtopic.find(subtopicID, on: conn)
    }
}
