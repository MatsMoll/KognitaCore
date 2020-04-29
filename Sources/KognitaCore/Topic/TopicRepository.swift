//
//  TopicRepository.swift
//  KognitaCore
//
//  Created by Mats Mollestad on 10/04/2019.
//

import FluentPostgreSQL
import Vapor

public protocol TopicRepository: CreateModelRepository,
    UpdateModelRepository,
    DeleteModelRepository,
    RetriveAllModelsRepository
    where
    Model           == Topic,
    ResponseModel   == Topic,
    CreateData      == Topic.Create.Data,
    CreateResponse  == Topic.Create.Response,
    UpdateData      == Topic.Edit.Data,
    UpdateResponse  == Topic.Edit.Response {
    static func getTopics(in subject: Subject, conn: DatabaseConnectable) throws -> EventLoopFuture<[Topic]>
}

public struct TimelyTopic: Codable {
    public let subjectName: String
    public let topicName: String
    public let topicID: Int
    public let numberOfTasks: Int
}

struct TopicTaskCount: Codable {
    let taskCount: Int
}

public struct CompetenceData {
    public let userScore: Double
    public let maxScore: Double

    public var percentage: Double {
        guard maxScore > 0 else {
            return 0
        }
        return ((userScore / maxScore) * 10000).rounded() / 100
    }

    public init(userScore: Double, maxScore: Double) {
        self.userScore = userScore
        self.maxScore = maxScore
    }
}

extension Topic {

    public struct UserOverview: Content {
        public let id: Topic.ID
        public let name: String
        public let numberOfTasks: Int
        public let userLevel: User.TopicLevel

        public var competence: CompetenceData {
            .init(userScore: userLevel.correctScore, maxScore: userLevel.maxScore)
        }
    }

    public struct WithTaskCount: Content {
        public let topic: Topic
        public let taskCount: Int
    }
}

extension Topic {
    public final class DatabaseRepository {}
}

extension Topic.DatabaseRepository: TopicRepository {

    public static func create(from content: Topic.Create.Data, by user: User?, on conn: DatabaseConnectable) throws -> EventLoopFuture<Topic.Create.Response> {

        guard let user = user else { throw Abort(.forbidden) }

        return try User.DatabaseRepository
            .isModerator(user: user, subjectID: content.subjectId, on: conn)
            .flatMap { _ in

                Subject.DatabaseRepository
                    .getSubjectWith(id: content.subjectId, on: conn)
                    .flatMap { subject in

                        try Topic(content: content, subject: subject, creator: user)
                            .create(on: conn)
                            .flatMap { topic in
                                try Subtopic(
                                    content: Subtopic.Create.Data(
                                        name: "Generelt",
                                        topicId: topic.requireID()
                                    )
                                )
                                .save(on: conn)
                                .transform(to: topic)
                        }
                }
        }
    }

    public static func numberOfTasks(in topic: Topic, on conn: DatabaseConnectable) throws -> EventLoopFuture<Int> {
        return try Task.query(on: conn)
            .join(\Subtopic.id, to: \Task.subtopic)
            .filter(\Subtopic.topicId == topic.requireID())
            .count()
    }

    public static func tasks(in topic: Topic, on conn: DatabaseConnectable) throws -> EventLoopFuture<[Task]> {
        return try Task.query(on: conn)
            .join(\Subtopic.id, to: \Task.subtopic)
            .filter(\Subtopic.topicId == topic.requireID())
            .all()
    }

    public static func subtopics(in topic: Topic, on conn: DatabaseConnectable) throws -> EventLoopFuture<[Subtopic]> {
        return try Subtopic.DatabaseRepository
            .getSubtopics(in: topic, with: conn)
    }

    public static func subtopics(with topicID: Topic.ID, on conn: DatabaseConnectable) -> EventLoopFuture<[Subtopic]> {
        return Subtopic.DatabaseRepository
            .subtopics(with: topicID, on: conn)
    }

    public static func content(for topic: Topic, on conn: DatabaseConnectable) throws -> EventLoopFuture<Topic.Response> {
        return try subtopics(in: topic, on: conn)
            .map { subtopics in
                Topic.Response(topic: .init(topic: topic), subtopics: subtopics.map { .init(subtopic: $0) })
        }
    }

    public static func getAll(on conn: DatabaseConnectable) -> EventLoopFuture<[Topic]> {
        return Topic
            .query(on: conn)
            .all()
    }

    public static func getTopics(in subject: Subject, conn: DatabaseConnectable) throws -> EventLoopFuture<[Topic]> {
        return try subject
            .topics
            .query(on: conn)
            .sort(\.chapter, .ascending)
            .all()
    }

    public static func getTopicsWithTaskCount(in subject: Subject, conn: DatabaseConnectable) throws -> EventLoopFuture<[Topic.WithTaskCount]> {

        conn.databaseConnection(to: .psql)
            .flatMap { psqlConn in
                try psqlConn.select()
                    .all(table: Topic.self)
                    .from(Topic.self)
                    .column(.count(\Task.id), as: "taskCount")
                    .join(\Topic.id, to: \Subtopic.topicId)
                    .join(\Subtopic.id, to: \Task.subtopicID)
                    .groupBy(\Topic.id)
                    .where(\Topic.subjectId == subject.requireID())
                    .where(\Task.isTestable == false)
                    .all(decoding: Topic.self, TopicTaskCount.self)
                    .map { topics in
                        topics.map { data in
                            Topic.WithTaskCount(
                                topic: data.0,
                                taskCount: data.1.taskCount
                            )
                        }
                        .sorted(by: { $0.topic.chapter < $1.topic.chapter })
            }
        }
   }

    public static func getTopicResponses(in subject: Subject, conn: DatabaseConnectable) throws -> EventLoopFuture<[Topic.Response]> {
        return try getTopics(in: subject, conn: conn)
            .flatMap { topics in
                try topics.map {
                    try $0.content(on: conn)
                }
                .flatten(on: conn)
        }
    }

    public static func getTopic(for task: Task, on conn: DatabaseConnectable) -> EventLoopFuture<Topic> {
        return task.topic(on: conn)
    }

    public static func timelyTopics(limit: Int? = 4, on conn: PostgreSQLConnection) throws -> EventLoopFuture<[TimelyTopic]> {

        return conn.select()
            .column(\Subject.name, as: "subjectName")
            .column(\Topic.name, as: "topicName")
            .column(\Topic.id, as: "topicID")
            .column(.count(\Task.id), as: "numberOfTasks")
            .from(Subject.self)
            .join(\Subject.id, to: \Topic.subjectId)
            .join(\Topic.id, to: \Subtopic.topicId, method: .left)
            .join(\Subtopic.id, to: \Task.subtopicID, method: .left)
            .where(\Task.deletedAt == nil)
            .groupBy(\Topic.id)
            .groupBy(\Subject.id)
            .limit(limit)
            .all(decoding: TimelyTopic.self)
    }

    public static func exportTopics(in subject: Subject, on conn: DatabaseConnectable) throws -> EventLoopFuture<SubjectExportContent> {
        return try getTopics(in: subject, conn: conn)
            .flatMap { topics in
                try topics.map { try Topic.DatabaseRepository.exportTasks(in: $0, on: conn) }
                    .flatten(on: conn)
        }.map { topicContent in
            SubjectExportContent(subject: subject, topics: topicContent)
        }
    }

    public static func exportTasks(in topic: Topic, on conn: DatabaseConnectable) throws -> EventLoopFuture<TopicExportContent> {
        return try Subtopic.query(on: conn)
            .filter(\.topicId == topic.requireID())
            .all()
            .flatMap { subtopics in
                try subtopics.map {
                    try Topic.DatabaseRepository.exportTasks(in: $0, on: conn)
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

    public static func exportTasks(in subtopic: Subtopic, on conn: DatabaseConnectable) throws -> EventLoopFuture<SubtopicExportContent> {
        return conn.databaseConnection(to: .psql)
            .flatMap { psqlConn in

                try psqlConn.select()
                    .all(table: Task.self)
                    .all(table: MultipleChoiseTask.self)
                    .all(table: MultipleChoiseTaskChoise.self)
                    .column(\TaskSolution.solution, as: "solution")
                    .from(Task.self)
                    .join(\Task.id, to: \MultipleChoiseTask.id, method: .left)
                    .join(\Task.id, to: \FlashCardTask.id, method: .left)
                    .join(\MultipleChoiseTask.id, to: \MultipleChoiseTaskChoise.taskId, method: .left)
                    .join(\Task.id, to: \TaskSolution.taskID, method: .left)
                    .where(\Task.subtopicID == subtopic.requireID())
                    .all(decoding: Task.BetaFormat.self, MultipleChoiseTask?.self, MultipleChoiseTaskChoise?.self)
                    .map { tasks in

                        var multipleTasks = [Int: MultipleChoiseTask.BetaFormat]()
                        var flashTasks = [Task.BetaFormat]()

                        for task in tasks {
                            if
                                let multiple = task.1,
                                let choise = task.2
                            {
                                if let earlierTask = multipleTasks[multiple.id ?? 0] {
                                    multipleTasks[multiple.id ?? 0] = MultipleChoiseTask.BetaFormat(
                                        task: task.0,
                                        choises: earlierTask.choises + [choise],
                                        isMultipleSelect: multiple.isMultipleSelect
                                    )
                                } else {
                                    multipleTasks[multiple.id ?? 0] = MultipleChoiseTask.BetaFormat(
                                        task: task.0,
                                        choises: [choise],
                                        isMultipleSelect: multiple.isMultipleSelect
                                    )
                                }
                            } else {
                                flashTasks.append(task.0)
                            }
                        }

                        return SubtopicExportContent(
                            subtopic: subtopic,
                            multipleChoiseTasks: multipleTasks.map { $0.value },
                            flashCards: flashTasks
                        )
                }
        }
    }

    public static func importContent(from content: TopicExportContent, in subject: Subject, on conn: DatabaseConnectable) throws -> EventLoopFuture<Void> {

        content.topic.id = nil
        try content.topic.subjectId = subject.requireID()
        return content.topic
            .create(on: conn)
            .flatMap { topic in
                try content.subtopics.map {
                    try Topic.DatabaseRepository.importContent(from: $0, in: topic, on: conn)
                }
                .flatten(on: conn)
        }.transform(to: ())
    }

    public static func importContent(from content: SubtopicExportContent, in topic: Topic, on conn: DatabaseConnectable) throws -> EventLoopFuture<Void> {

        content.subtopic.id = nil
        content.subtopic.topicId = try topic.requireID()

        return content.subtopic
            .create(on: conn)
            .flatMap { subtopic in
                try content.multipleChoiseTasks
                    .map { task in
                        try MultipleChoiseTask.DatabaseRepository
                            .importTask(from: task, in: subtopic, on: conn)
                }.flatten(on: conn).flatMap { _ in
                    try content.flashCards
                    .map { task in
                        try FlashCardTask.DatabaseRepository
                            .importTask(from: task, in: subtopic, on: conn)
                    }.flatten(on: conn)
                }
        }.transform(to: ())
    }

//    public static func leveledTopics(in subject: Subject, on conn: DatabaseConnectable) throws -> EventLoopFuture<[[Topic]]> {
//
//        return try getTopics(in: subject, conn: conn)
//            .flatMap { topics in
//
//                try topicPreknowleged(in: subject, on: conn)
//                    .map { preknowleged in
//
//                        structure(topics, with: preknowleged)
//                }
//        }
//    }

//    static func topicPreknowleged(in subject: Subject, on conn: DatabaseConnectable) throws -> EventLoopFuture<[Topic.Pivot.Preknowleged]> {
//        throw Abort(.internalServerError)
//        return try Topic.Pivot.Preknowleged.query(on: conn)
//            .join(\Topic.id, to: \Topic.Pivot.Preknowleged.topicID)
//            .filter(\Topic.subjectId == subject.requireID())
//            .all()
//    }

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

public struct SubtopicExportContent: Content {
    let subtopic: Subtopic
    let multipleChoiseTasks: [MultipleChoiseTask.BetaFormat]
    let flashCards: [Task.BetaFormat]
}

public struct TopicExportContent: Content {
    let topic: Topic
    let subtopics: [SubtopicExportContent]
}

public struct SubjectExportContent: Content {
    let subject: Subject
    let topics: [TopicExportContent]
}

extension MultipleChoiseTask {
    public struct BetaFormat: Content {

        let task: Task.BetaFormat

        let choises: [MultipleChoiseTaskChoise]

        let isMultipleSelect: Bool
    }
}
