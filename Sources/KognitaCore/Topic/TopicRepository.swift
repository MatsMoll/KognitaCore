//
//  TopicRepository.swift
//  KognitaCore
//
//  Created by Mats Mollestad on 10/04/2019.
//

import FluentPostgreSQL
import Vapor
import FluentQuery


public struct TimelyTopic: Codable {
    public let subjectName: String
    public let topicName: String
    public let topicID: Int
    public let numberOfTasks: Int
}

public class TopicRepository {

    public static let shared = TopicRepository()

    public func getAll(on conn: DatabaseConnectable) -> Future<[Topic]> {
        return Topic
            .query(on: conn)
            .all()
    }

    public func getAll(in subject: Subject, conn: DatabaseConnectable) throws -> Future<[Topic]> {
        let subjectId = try subject.requireID()
        return Topic.query(on: conn)
            .filter(\.subjectId == subjectId)
            .all()
    }

    public func getTopics(in subject: Subject, conn: DatabaseConnectable) throws -> Future<[Topic]> {
        return try subject
            .topics
            .query(on: conn)
            .sort(\.chapter, .ascending)
            .all()
    }

    public func getTopic(for task: Task, on conn: DatabaseConnectable) -> Future<Topic> {
        return task.topic.get(on: conn)
    }

    public func create(with content: TopicCreateContent, user: User, conn: DatabaseConnectable) throws -> Future<Topic> {

        guard user.isCreator else {
            throw Abort(.forbidden)
        }

        return SubjectRepository
            .shared
            .getSubjectWith(id: content.subjectId, on: conn)
            .flatMap { subject in
                try Topic(content: content, subject: subject, creator: user)
                    .create(on: conn)
        }
    }

    public func delete(topic: Topic, user: User, on conn: DatabaseConnectable) throws -> Future<Void> {
        guard user.isCreator else {
            throw Abort(.forbidden)
        }
        return topic.delete(on: conn)
    }

    public func edit(topic: Topic, with content: TopicCreateContent, user: User, on conn: DatabaseConnectable) throws -> Future<Topic> {
        guard user.isCreator else {
            throw Abort(.forbidden)
        }
        try topic.updateValues(with: content)
        return topic.save(on: conn)
    }

    public func timelyTopics(on conn: PostgreSQLConnection) throws -> Future<[TimelyTopic]> {

        let numberOfTasksKey = "numberOfTasks"
        let alias = Topic.alias(short: "sub")

        return try FQL()
            .select(\Subject.name, as: "subjectName")
            .select(alias.k(\.name), as: "topicName")
            .select(alias.k(\.id), as: "topicID")
            .select("\"sub\".\"\(numberOfTasksKey)\" as \"\(numberOfTasksKey)\"")
            .from(Subject.self)
            .orderBy(.asc(numberOfTasksKey))
//            .limit(12)
            .join(
                .inner,
                subquery: FQL()
                    .select(\Topic.subjectId)
                    .select(\Topic.name)
                    .select(\Topic.id)
                    .select(.count(\Task.isOutdated), as: numberOfTasksKey)
                    .from(Topic.self)
                    .join(.left, Task.self, where: \Task.topicId == \Topic.id)
                    .where(
                        FQWhere(\Task.isOutdated == false).or(\Task.isOutdated == nil)
                    )
                    .groupBy(\Topic.id),
                alias: alias,
                where: \Subject.id == alias.k(\.subjectId)
            )
            .execute(on: conn, andDecode: TimelyTopic.self)

    }
}
