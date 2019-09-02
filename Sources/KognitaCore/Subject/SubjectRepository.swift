//
//  SubjectRepository.swift
//  App
//
//  Created by Mats Mollestad on 02/03/2019.
//

import Vapor
import FluentPostgreSQL

extension Subject {
    public final class Repository : KognitaRepository, KognitaRepositoryDeletable, KognitaRepositoryEditable {
        
        public typealias Model = Subject
        
        public static var shared = Repository()
    }
}

extension Subject.Repository {

    public func create(from content: Subject.Create.Data, by user: User?, on conn: DatabaseConnectable) throws -> EventLoopFuture<Subject> {
        guard let user = user, user.isCreator else {
            throw Abort(.forbidden)
        }
        return try Subject(content: content, creator: user)
            .create(on: conn)
    }

    public func getSubjectWith(id: Subject.ID, on conn: DatabaseConnectable) -> Future<Subject> {
        return Subject
            .find(id, on: conn)
            .unwrap(or: Abort(.badRequest))
    }

    public func getSubject(in topic: Topic, on conn: DatabaseConnectable) -> Future<Subject> {
        return topic.subject.get(on: conn)
    }

    public func importContent(_ content: SubjectExportContent, on conn: DatabaseConnectable) -> Future<Subject> {
        content.subject.id = nil
        content.subject.creatorId = 1
        return conn.transaction(on: .psql) { conn in
            content.subject.create(on: conn).flatMap { subject in
                try content.topics.map { try Topic.repository.importContent(from: $0, in: subject, on: conn) }
                    .flatten(on: conn)
                    .transform(to: subject)
            }
        }
    }
}


extension Subject {
    public struct Create : KognitaRequestData {
        public struct Data : Content {
            let name: String
            let colorClass: Subject.ColorClass
            let description: String
            let category: String
        }
        
        public typealias Response = Subject
    }
    
    public typealias Edit = Create
}
