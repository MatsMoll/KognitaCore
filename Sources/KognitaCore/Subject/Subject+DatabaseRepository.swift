//
//  Subject+DatabaseRepository.swift
//  KognitaCore
//
//  Created by Mats Mollestad on 23/12/2019.
//

import Vapor

extension Subject {
    public final class DatabaseRepository: SubjectRepositoring {}
}

extension Subject.DatabaseRepository {

    public static func create(from content: Subject.Create.Data, by user: User?, on conn: DatabaseConnectable) throws -> EventLoopFuture<Subject> {
        guard let user = user, user.isCreator else {
            throw Abort(.forbidden)
        }
        return try Subject(content: content, creator: user)
            .create(on: conn)
    }

    public static func getSubjectWith(id: Subject.ID, on conn: DatabaseConnectable) -> EventLoopFuture<Subject> {
        return Subject
            .find(id, on: conn)
            .unwrap(or: Abort(.badRequest))
    }

    public static func getSubject(in topic: Topic, on conn: DatabaseConnectable) -> EventLoopFuture<Subject> {
        return topic.subject.get(on: conn)
    }

    public static func importContent(_ content: SubjectExportContent, on conn: DatabaseConnectable) -> EventLoopFuture<Subject> {
        content.subject.id = nil
        content.subject.creatorId = 1
        return conn.transaction(on: .psql) { conn in
            content.subject.create(on: conn).flatMap { subject in
                try content.topics.map { try Topic.DatabaseRepository.importContent(from: $0, in: subject, on: conn) }
                    .flatten(on: conn)
                    .transform(to: subject)
            }
        }
    }

//    public static func leaderboard(in subject: Subject, for user: User, on conn: DatabaseConnectable) -> EventLoopFuture<Subject.Leaderboard> {
//        return conn.databaseConnection(to: .psql).flatMap { psqlConn in
//            psqlConn.select()
//                .column(.sum(\TaskResult.resultScore), as: "score")
//                .all(table: User.self)
//        }
//        return try User.query(on: conn)
//            .join(\TaskResult.userID, to: \User.id)
//            .join(\Task.id, to: \TaskResult.taskID)
//            .join(\Subtopic.id, to: \Task.subtopicId)
//            .join(\Topic.id, to: \Subtopic.topicId)
//            .filter(\Topic.subjectId == subject.requireID())
//    }
}
