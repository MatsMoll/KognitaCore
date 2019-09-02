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

extension Topic {
    public final class Repository : KognitaRepository, KognitaRepositoryEditable, KognitaRepositoryDeletable {
        
        public typealias Model = Topic
        
        public static let shared = Repository()
    }
}

extension Topic.Repository {
    
    public func create(from content: Topic.Create.Data, by user: User?, on conn: DatabaseConnectable) throws -> EventLoopFuture<Topic.Create.Response> {
        
        guard let user = user,
            user.isCreator else { throw Abort(.forbidden) }

        return Subject.Repository
            .shared
            .getSubjectWith(id: content.subjectId, on: conn)
            .flatMap { subject in
                try Topic(content: content, subject: subject, creator: user)
                    .create(on: conn)
        }
    }

    public func numberOfTasks(in topic: Topic, on conn: DatabaseConnectable) throws -> Future<Int> {
        return try Task.query(on: conn)
            .join(\Subtopic.id, to: \Task.subtopic)
            .filter(\Subtopic.topicId == topic.requireID())
            .count()
    }
    
    public func tasks(in topic: Topic, on conn: DatabaseConnectable) throws -> Future<[Task]> {
        return try Task.query(on: conn)
            .join(\Subtopic.id, to: \Task.subtopic)
            .filter(\Subtopic.topicId == topic.requireID())
            .all()
    }
    
    public func subtopics(in topic: Topic, on conn: DatabaseConnectable) throws -> Future<[Subtopic]> {
        return try Subtopic.Repository.shared
            .getSubtopics(in: topic, with: conn)
    }

    public func content(for topic: Topic, on conn: DatabaseConnectable) throws -> Future<Topic.Response> {
        return try subtopics(in: topic, on: conn)
            .map { subtopics in
                Topic.Response(topic: topic, subtopics: subtopics)
        }
    }
    
    public func getAll(on conn: DatabaseConnectable) -> Future<[Topic]> {
        return Topic
            .query(on: conn)
            .all()
    }

    public func getTopics(in subject: Subject, conn: DatabaseConnectable) throws -> Future<[Topic]> {
        return try subject
            .topics
            .query(on: conn)
            .sort(\.chapter, .ascending)
            .all()
    }

    public func getTopicResponses(in subject: Subject, conn: DatabaseConnectable) throws -> Future<[Topic.Response]> {
        return try getTopics(in: subject, conn: conn)
            .flatMap { topics in
                try topics.map {
                    try $0.content(on: conn)
                }
                .flatten(on: conn)
        }
    }

    public func getTopic(for task: Task, on conn: DatabaseConnectable) -> Future<Topic> {
        return task.topic(on: conn)
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
            .limit(12)
            .join(
                .inner,
                subquery: FQL()
                    .select(\Topic.subjectId)
                    .select(\Topic.name)
                    .select(\Topic.id)
                    .select(.count(\Task.id), as: numberOfTasksKey)
                    .from(Topic.self)
                    .join(.inner, Subtopic.self, where: \Subtopic.topicId == \Topic.id)
                    .join(.left, Task.self, where: \Task.subtopicId == \Subtopic.id)
                    .where(
                        \Task.deletedAt == nil
                    )
                    .groupBy(\Topic.id),
                alias: alias,
                where: \Subject.id == alias.k(\.subjectId)
            )
            .execute(on: conn, andDecode: TimelyTopic.self)

    }

    public func exportTopics(in subject: Subject, on conn: DatabaseConnectable) throws -> Future<SubjectExportContent> {
        return try getTopics(in: subject, conn: conn)
            .flatMap { topics in
                try topics.map { try Topic.Repository.shared.exportTasks(in: $0, on: conn) }
                    .flatten(on: conn)
        }.map { topicContent in
            SubjectExportContent(subject: subject, topics: topicContent)
        }
    }

    public func exportTasks(in topic: Topic, on conn: DatabaseConnectable) throws -> Future<TopicExportContent> {
        return try Subtopic.query(on: conn)
            .filter(\.topicId == topic.requireID())
            .all()
            .flatMap { subtopics in
                try subtopics.map {
                    try Topic.Repository.shared.exportTasks(in: $0, on: conn)
                }
                .flatten(on: conn)
                .map { subtopicContent in
                    TopicExportContent(
                        topic: topic,
                        subtopics: subtopicContent
                    )
                }
        }
    }

    public func exportTasks(in subtopic: Subtopic, on conn: DatabaseConnectable) throws -> Future<SubtopicExportContent> {
        return try MultipleChoiseTask.query(on: conn)
            .join(\Task.id, to: \MultipleChoiseTask.id)
            .filter(\Task.subtopicId == subtopic.requireID())
            .all()
            .flatMap { tasks in
                try tasks.map { try MultipleChoiseTask.repository.get(task: $0, conn: conn) }
                    .flatten(on: conn)
        }.flatMap { multipleTasks in
            try NumberInputTask.query(on: conn)
                .join(\Task.id, to: \NumberInputTask.id)
                .filter(\Task.subtopicId == subtopic.requireID())
                .all()
                .flatMap { tasks in
                    try tasks.map { try NumberInputTask.repository.get(task: $0, conn: conn) }
                        .flatten(on: conn)
            }.flatMap { numberTasks in
                try FlashCardTask.query(on: conn)
                    .join(\Task.id, to: \FlashCardTask.id)
                    .filter(\Task.subtopicId == subtopic.requireID())
                    .all()
                    .flatMap { tasks in
                        try tasks.map { try FlashCardTask.repository.get(task: $0, conn: conn) }
                            .flatten(on: conn)
                }.map { flashCards in
                    SubtopicExportContent(
                        subtopic: subtopic,
                        multipleChoiseTasks: multipleTasks,
                        inputTasks: numberTasks,
                        flashCards: flashCards
                    )
                }
            }
        }
    }

    public func importContent(from content: TopicExportContent, in subject: Subject, on conn: DatabaseConnectable) throws -> Future<Void> {

        content.topic.id = nil
        content.topic.creatorId = 1
        try content.topic.subjectId = subject.requireID()
        return content.topic
            .create(on: conn)
            .flatMap { topic in
                try content.subtopics.map {
                    try Topic.repository.importContent(from: $0, in: topic, on: conn)
                }
                .flatten(on: conn)
        }.transform(to: ())
    }


    public func importContent(from content: SubtopicExportContent, in topic: Topic, on conn: DatabaseConnectable) throws -> Future<Void> {

        content.subtopic.id = nil
        content.subtopic.topicId = try topic.requireID()

        return content.subtopic
            .create(on: conn)
            .flatMap { subtopic in
                try content.multipleChoiseTasks
                    .map { task in
                        try MultipleChoiseTask.repository
                            .importTask(from: task, in: subtopic, on: conn)
                }.flatten(on: conn).flatMap { _ in
                    try content.inputTasks
                    .map { task in
                        try NumberInputTask.repository
                            .importTask(from: task, in: subtopic, on: conn)
                    }.flatten(on: conn).flatMap { _ in
                        try content.flashCards
                        .map { task in
                            try FlashCardTask.repository
                                .importTask(from: task, in: subtopic, on: conn)
                        }.flatten(on: conn)
                    }
                }
        }.transform(to: ())
    }
}

public struct SubtopicExportContent : Content {
    let subtopic: Subtopic
    let multipleChoiseTasks: [MultipleChoiseTask.Data]
    let inputTasks: [NumberInputTask.Data]
    let flashCards: [Task]
}

public struct TopicExportContent: Content {
    let topic: Topic
    let subtopics: [SubtopicExportContent]
}

public struct SubjectExportContent: Content {
    let subject: Subject
    let topics: [TopicExportContent]
}
