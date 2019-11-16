//
//  TopicRepository.swift
//  KognitaCore
//
//  Created by Mats Mollestad on 10/04/2019.
//

import FluentPostgreSQL
import Vapor

public struct TimelyTopic: Codable {
    public let subjectName: String
    public let topicName: String
    public let topicID: Int
    public let numberOfTasks: Int
}

extension Topic {
    public final class Repository : KognitaRepository, KognitaRepositoryEditable, KognitaRepositoryDeletable {
        
        public typealias Model = Topic
    }
}

extension Topic.Repository {
    
    public static func create(from content: Topic.Create.Data, by user: User?, on conn: DatabaseConnectable) throws -> EventLoopFuture<Topic.Create.Response> {
        
        guard let user = user,
            user.isCreator else { throw Abort(.forbidden) }

        return Subject.Repository
            .getSubjectWith(id: content.subjectId, on: conn)
            .flatMap { subject in
                try Topic(content: content, subject: subject, creator: user)
                    .create(on: conn)
        }
    }

    public static func numberOfTasks(in topic: Topic, on conn: DatabaseConnectable) throws -> Future<Int> {
        return try Task.query(on: conn)
            .join(\Subtopic.id, to: \Task.subtopic)
            .filter(\Subtopic.topicId == topic.requireID())
            .count()
    }
    
    public static func tasks(in topic: Topic, on conn: DatabaseConnectable) throws -> Future<[Task]> {
        return try Task.query(on: conn)
            .join(\Subtopic.id, to: \Task.subtopic)
            .filter(\Subtopic.topicId == topic.requireID())
            .all()
    }
    
    public static func subtopics(in topic: Topic, on conn: DatabaseConnectable) throws -> Future<[Subtopic]> {
        return try Subtopic.Repository
            .getSubtopics(in: topic, with: conn)
    }

    public static func subtopics(with topicID: Topic.ID, on conn: DatabaseConnectable) -> Future<[Subtopic]> {
        return Subtopic.Repository
            .subtopics(with: topicID, on: conn)
    }

    public static func content(for topic: Topic, on conn: DatabaseConnectable) throws -> Future<Topic.Response> {
        return try subtopics(in: topic, on: conn)
            .map { subtopics in
                Topic.Response(topic: topic, subtopics: subtopics)
        }
    }
    
    public static func getAll(on conn: DatabaseConnectable) -> Future<[Topic]> {
        return Topic
            .query(on: conn)
            .all()
    }

    public static func getTopics(in subject: Subject, conn: DatabaseConnectable) throws -> Future<[Topic]> {
        return try subject
            .topics
            .query(on: conn)
            .sort(\.chapter, .ascending)
            .all()
    }

    public static func getTopicResponses(in subject: Subject, conn: DatabaseConnectable) throws -> Future<[Topic.Response]> {
        return try getTopics(in: subject, conn: conn)
            .flatMap { topics in
                try topics.map {
                    try $0.content(on: conn)
                }
                .flatten(on: conn)
        }
    }

    public static func getTopic(for task: Task, on conn: DatabaseConnectable) -> Future<Topic> {
        return task.topic(on: conn)
    }

    public static func timelyTopics(limit: Int? = 4, on conn: PostgreSQLConnection) throws -> Future<[TimelyTopic]> {

        return conn.select()
            .column(\Subject.name,      as: "subjectName")
            .column(\Topic.name,        as: "topicName")
            .column(\Topic.id,          as: "topicID")
            .column(.count(\Task.id),   as: "numberOfTasks")
            .from(Subject.self)
            .join(\Subject.id,          to: \Topic.subjectId)
            .join(\Topic.id,            to: \Subtopic.topicId, method: .left)
            .join(\Subtopic.id,         to: \Task.subtopicId,  method: .left)
            .where(\Task.deletedAt == nil)
            .groupBy(\Topic.id)
            .groupBy(\Subject.id)
            .limit(limit)
            .all(decoding: TimelyTopic.self)
    }

    public static func exportTopics(in subject: Subject, on conn: DatabaseConnectable) throws -> Future<SubjectExportContent> {
        return try getTopics(in: subject, conn: conn)
            .flatMap { topics in
                try topics.map { try Topic.Repository.exportTasks(in: $0, on: conn) }
                    .flatten(on: conn)
        }.map { topicContent in
            SubjectExportContent(subject: subject, topics: topicContent)
        }
    }

    public static func exportTasks(in topic: Topic, on conn: DatabaseConnectable) throws -> Future<TopicExportContent> {
        return try Subtopic.query(on: conn)
            .filter(\.topicId == topic.requireID())
            .all()
            .flatMap { subtopics in
                try subtopics.map {
                    try Topic.Repository.exportTasks(in: $0, on: conn)
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

    public static func exportTasks(in subtopic: Subtopic, on conn: DatabaseConnectable) throws -> Future<SubtopicExportContent> {
        return try MultipleChoiseTask.query(on: conn)
            .join(\Task.id, to: \MultipleChoiseTask.id)
            .filter(\Task.subtopicId == subtopic.requireID())
            .all()
            .flatMap { tasks in
                try tasks.map { try MultipleChoiseTask.Repository.get(task: $0, conn: conn) }
                    .flatten(on: conn)
        }.flatMap { multipleTasks in
            try NumberInputTask.query(on: conn)
                .join(\Task.id, to: \NumberInputTask.id)
                .filter(\Task.subtopicId == subtopic.requireID())
                .all()
                .flatMap { tasks in
                    try tasks.map { try NumberInputTask.Repository.get(task: $0, conn: conn) }
                        .flatten(on: conn)
            }.flatMap { numberTasks in
                try FlashCardTask.query(on: conn)
                    .join(\Task.id, to: \FlashCardTask.id)
                    .filter(\Task.subtopicId == subtopic.requireID())
                    .all()
                    .flatMap { tasks in
                        try tasks.map { try FlashCardTask.Repository.get(task: $0, conn: conn) }
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

    public static func importContent(from content: TopicExportContent, in subject: Subject, on conn: DatabaseConnectable) throws -> Future<Void> {

        content.topic.id = nil
        content.topic.creatorId = 1
        try content.topic.subjectId = subject.requireID()
        return content.topic
            .create(on: conn)
            .flatMap { topic in
                try content.subtopics.map {
                    try Topic.Repository.importContent(from: $0, in: topic, on: conn)
                }
                .flatten(on: conn)
        }.transform(to: ())
    }


    public static func importContent(from content: SubtopicExportContent, in topic: Topic, on conn: DatabaseConnectable) throws -> Future<Void> {

        content.subtopic.id = nil
        content.subtopic.topicId = try topic.requireID()

        return content.subtopic
            .create(on: conn)
            .flatMap { subtopic in
                try content.multipleChoiseTasks
                    .map { task in
                        try MultipleChoiseTask.Repository
                            .importTask(from: task, in: subtopic, on: conn)
                }.flatten(on: conn).flatMap { _ in
                    try content.inputTasks
                    .map { task in
                        try NumberInputTask.Repository
                            .importTask(from: task, in: subtopic, on: conn)
                    }.flatten(on: conn).flatMap { _ in
                        try content.flashCards
                        .map { task in
                            try FlashCardTask.Repository
                                .importTask(from: task, in: subtopic, on: conn)
                        }.flatten(on: conn)
                    }
                }
        }.transform(to: ())
    }

    public static func leveledTopics(in subject: Subject, on conn: DatabaseConnectable) throws -> Future<[[Topic]]> {

        return try getTopics(in: subject, conn: conn)
            .flatMap { topics in

                try topicPreknowleged(in: subject, on: conn)
                    .map { preknowleged in

                        structure(topics, with: preknowleged)
                }
        }
    }

    static func topicPreknowleged(in subject: Subject, on conn: DatabaseConnectable) throws -> Future<[Topic.Pivot.Preknowleged]> {
        return try Topic.Pivot.Preknowleged.query(on: conn)
            .join(\Topic.id, to: \Topic.Pivot.Preknowleged.topicID)
            .filter(\Topic.subjectId == subject.requireID())
            .all()
    }

    static func structure(_ topics: [Topic], with preknowleged: [Topic.Pivot.Preknowleged]) -> [[Topic]] {
        var knowlegedGraph = [Topic.ID: [Topic.ID]]()
        for knowleged in preknowleged {
            if let value = knowlegedGraph[knowleged.topicID] {
                knowlegedGraph[knowleged.topicID] = value + [knowleged.preknowlegedID]
            } else {
                knowlegedGraph[knowleged.topicID] = [knowleged.preknowlegedID]
            }
        }
        var levels = [Topic.ID: Int]()
        var unleveledTopics = topics
        var topicIndex = unleveledTopics.count - 1
        while topicIndex >= 0 {
            let currentTopic = unleveledTopics[topicIndex]
            guard let currentTopicID = try? currentTopic.requireID() else {
                unleveledTopics.remove(at: topicIndex)
                topicIndex -= 1
                continue
            }
            if let node = knowlegedGraph[currentTopicID] {
                let preLevels = node.compactMap { levels[$0] }
                if preLevels.count == node.count {
                    levels[currentTopicID] = preLevels.reduce(1) { max($0, $1) } + 1
                    unleveledTopics.remove(at: topicIndex)
                }
            } else {
                unleveledTopics.remove(at: topicIndex)
                levels[currentTopicID] = 1
            }

            if topicIndex >= 1 {
                topicIndex -= 1
            } else {
                topicIndex = unleveledTopics.count - 1
            }
        }
        var leveledTopics = [[Topic]]()
        for (topicID, level) in levels.sorted(by: { $0.1 < $1.1 }) {
            if leveledTopics.count < level {
                leveledTopics.append([])
            }
            if let topic = topics.first(where: { $0.id == topicID }) {
                leveledTopics[level - 1] = leveledTopics[level - 1] + [topic]
            }
        }
        return leveledTopics.map { level in level.sorted(by: { $0.chapter < $1.chapter }) }
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
