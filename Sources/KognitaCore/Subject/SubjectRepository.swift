//
//  SubjectRepository.swift
//  App
//
//  Created by Mats Mollestad on 02/03/2019.
//

import Vapor
import FluentPostgreSQL

public class SubjectRepository {

    public static let shared = SubjectRepository()


    public func createSubject(with content: CreateSubjectRequest, for user: User, conn: DatabaseConnectable) throws -> Future<Subject> {
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

    public func getAll(on conn: DatabaseConnectable) -> Future<[Subject]> {
        return Subject
            .query(on: conn)
            .all()
    }

    public func edit(subject: Subject, with content: CreateSubjectRequest, user: User, conn: DatabaseConnectable) throws -> Future<Subject> {
        guard try subject.creatorId == user.requireID() else {
            throw Abort(.forbidden, reason: "You are not the creator of this content")
        }
        try subject.updateValues(with: content)
        return subject.save(on: conn)
    }

    public func delete(subject: Subject, user: User, conn: DatabaseConnectable) throws -> Future<Void> {
        guard try subject.creatorId == user.requireID() else {
            throw Abort(.forbidden, reason: "You are not the creator of this content")
        }
        return subject
            .delete(on: conn)
    }

    public func importContent(_ content: SubjectExportContent, on conn: DatabaseConnectable) -> Future<Subject> {
        content.subject.id = nil
        content.subject.creatorId = 1
        return conn.transaction(on: .psql) { conn in
            content.subject.create(on: conn).flatMap { subject in
                try content.topics.map { try TopicRepository.shared.importContent(from: $0, in: subject, on: conn) }
                    .flatten(on: conn)
                    .transform(to: subject)
            }
        }
    }
}


public struct CreateSubjectRequest: Content {
    let name: String
    let colorClass: String
    let description: String
    let category: String
}
