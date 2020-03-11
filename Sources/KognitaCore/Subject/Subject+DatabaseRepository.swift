//
//  Subject+DatabaseRepository.swift
//  KognitaCore
//
//  Created by Mats Mollestad on 23/12/2019.
//

import Vapor
import FluentPostgreSQL

extension Subject {
    public final class DatabaseRepository: SubjectRepositoring {}
}

extension Subject.DatabaseRepository {

    public static func create(from content: Subject.Create.Data, by user: User?, on conn: DatabaseConnectable) throws -> EventLoopFuture<Subject> {
        guard let user = user, user.isAdmin else {
            throw Abort(.forbidden)
        }
        return try Subject(content: content, creator: user)
            .create(on: conn)
            .flatMap { subject in

                try User.ModeratorPrivilege(userID: user.requireID(), subjectID: subject.requireID())
                    .create(on: conn)
                    .transform(to: subject)
        }
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

    public static func importContent(in subject: Subject, peerWise: [Task.PeerWise], user: User, on conn: DatabaseConnectable) throws -> EventLoopFuture<Void> {

        let knownTopic = peerWise.filter({ $0.topicName != "" })

        return try Topic.query(on: conn)
            .filter(\.subjectId == subject.requireID())
            .count()
            .flatMap { numberOfExistingTopics in

                var numberOfTopics = numberOfExistingTopics

                return try knownTopic
                    .group(by: \.topicName)
                    .map { topicName, tasks in

                        numberOfTopics += 1

                        return try Topic.DatabaseRepository.create(
                            from: Topic.Create.Data(
                                subjectId: subject.requireID(),
                                name: topicName,
                                chapter: numberOfTopics
                            ),
                            by: user,
                            on: conn
                        )
                            .flatMap { topic in
                                try Subtopic.DatabaseRepository
                                    .getSubtopics(in: topic, with: conn)
                                    .flatMap { subtopics in

                                        guard let subtopic = subtopics.first else { throw Abort(.internalServerError) }

                                        return try tasks.map { task in
                                            try MultipleChoiseTask.DatabaseRepository.create(
                                                from: MultipleChoiseTask.Create.Data(
                                                    subtopicId: subtopic.requireID(),
                                                    description: nil,
                                                    question: task.question,
                                                    solution: task.solution,
                                                    isMultipleSelect: false,
                                                    examPaperSemester: nil,
                                                    examPaperYear: nil,
                                                    isTestable: false,
                                                    choises: task.choises
                                                ),
                                                by: user,
                                                on: conn
                                            )
                                                .transform(to: ())
                                        }
                                        .flatten(on: conn)
                                }
                        }
                }
                .flatten(on: conn)
                .transform(to: ())
        }
    }

    public static func allActive(for user: User, on conn: DatabaseConnectable) throws -> EventLoopFuture<[Subject]> {

        return try Subject.query(on: conn)
            .join(\User.ActiveSubject.subjectID, to: \Subject.id, method: .left)
            .filter(\User.ActiveSubject.userID == user.requireID())
            .decode(Subject.self)
            .all()
    }

    struct SubjectID: Decodable {
        let subjectId: Subject.ID
    }

    static func subjectIDFor(taskIDs: [Task.ID], on conn: DatabaseConnectable) -> EventLoopFuture<Subject.ID> {

        return conn.databaseConnection(to: .psql)
            .flatMap { conn in

                conn.select()
                    .column(\Topic.subjectId)
                    .from(Task.self)
                    .join(\Task.subtopicID, to: \Subtopic.id)
                    .join(\Subtopic.topicId, to: \Topic.id)
                    .where(\Task.id, .in, taskIDs)
                    .groupBy(\Topic.subjectId)
                    .all(decoding: SubjectID.self)
                    .map { subjectIDs in
                        guard
                            subjectIDs.count == 1,
                            let id = subjectIDs.first?.subjectId
                        else {
                            throw Abort(.badRequest)
                        }
                        return id
                }
        }
    }

    static func subjectIDFor(topicIDs: [Topic.ID], on conn: DatabaseConnectable) -> EventLoopFuture<Subject.ID> {

        return conn.databaseConnection(to: .psql)
            .flatMap { conn in

                conn.select()
                    .column(\Topic.subjectId)
                    .from(Topic.self)
                    .where(\Topic.id, .in, topicIDs)
                    .groupBy(\Topic.subjectId)
                    .all(decoding: SubjectID.self)
                    .map { subjectIDs in
                        guard
                            subjectIDs.count == 1,
                            let id = subjectIDs.first?.subjectId
                        else {
                            throw Abort(.badRequest)
                        }
                        return id
                }
        }
    }

    static func subjectIDFor(subtopicIDs: [Subtopic.ID], on conn: DatabaseConnectable) -> EventLoopFuture<Subject.ID> {

        return conn.databaseConnection(to: .psql)
            .flatMap { conn in

                conn.select()
                    .column(\Topic.subjectId)
                    .from(Subtopic.self)
                    .join(\Subtopic.topicId, to: \Topic.id)
                    .where(\Subtopic.id, .in, subtopicIDs)
                    .groupBy(\Topic.subjectId)
                    .all(decoding: SubjectID.self)
                    .map { subjectIDs in
                        guard
                            subjectIDs.count == 1,
                            let id = subjectIDs.first?.subjectId
                        else {
                            throw Abort(.badRequest)
                        }
                        return id
                }
        }
    }

    public static func mark(active subject: Subject, canPractice: Bool, for user: User, on conn: DatabaseConnectable) throws -> EventLoopFuture<Void> {
        try User.ActiveSubject(
            userID: user.requireID(),
            subjectID: subject.requireID(),
            canPractice: canPractice
        )
            .create(on: conn)
            .transform(to: ())
    }

    public static func grantModeratorPrivilege(for userID: User.ID, in subjectID: Subject.ID, by moderator: User, on conn: DatabaseConnectable) throws -> EventLoopFuture<Void> {

        try User.DatabaseRepository
            .isModerator(user: moderator, subjectID: subjectID, on: conn)
            .flatMap {
                User.ModeratorPrivilege(
                    userID: userID,
                    subjectID: subjectID
                )
                    .create(on: conn)
                    .transform(to: ())
        }
    }

    public static func revokeModeratorPrivilege(for userID: User.ID, in subjectID: Subject.ID, by moderator: User, on conn: DatabaseConnectable) throws -> EventLoopFuture<Void> {
        guard moderator.id != userID else {
            throw Abort(.badRequest)
        }
        return try User.DatabaseRepository
            .isModerator(user: moderator, subjectID: subjectID, on: conn)
            .flatMap {

                User.ModeratorPrivilege.query(on: conn)
                    .filter(\.userID == userID)
                    .filter(\.subjectID == subjectID)
                    .first()
                    .unwrap(or: Abort(.badRequest))
                    .flatMap { privilege in

                        privilege.delete(on: conn)
                }
        }
    }

    public static func active(subject: Subject, for user: User, on conn: DatabaseConnectable) throws -> EventLoopFuture<User.ActiveSubject?> {

        try User.ActiveSubject.query(on: conn)
            .filter(\.userID == user.requireID())
            .filter(\.subjectID == subject.requireID())
            .first()
    }
}
