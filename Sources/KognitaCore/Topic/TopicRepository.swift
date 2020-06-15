//
//  TopicRepository.swift
//  KognitaCore
//
//  Created by Mats Mollestad on 10/04/2019.
//

import FluentPostgreSQL
import Vapor

public protocol TopicRepository: DeleteModelRepository {
    func all() throws -> EventLoopFuture<[Topic]>
    func find(_ id: Topic.ID, or error: Error) -> EventLoopFuture<Topic>
    func create(from content: Topic.Create.Data, by user: User?) throws -> EventLoopFuture<Topic.Create.Response>
    func updateModelWith(id: Int, to data: Topic.Update.Data, by user: User) throws -> EventLoopFuture<Topic.Update.Response>
    func getTopics(in subject: Subject) throws -> EventLoopFuture<[Topic]>
    func exportTasks(in topic: Topic) throws -> EventLoopFuture<TopicExportContent>
    func exportTopics(in subject: Subject) throws -> EventLoopFuture<SubjectExportContent>
    func getTopicResponses(in subject: Subject) throws -> EventLoopFuture<[Topic]>
    func importContent(from content: TopicExportContent, in subject: Subject) throws -> EventLoopFuture<Void>
    func importContent(from content: SubtopicExportContent, in topic: Topic) throws -> EventLoopFuture<Void>
    func getTopicsWithTaskCount(in subject: Subject) throws -> EventLoopFuture<[Topic.WithTaskCount]>
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
    public struct DatabaseRepository: DatabaseConnectableRepository {

        init(conn: DatabaseConnectable, repositories: RepositoriesRepresentable) {
            self.conn = conn
            self.userRepository = repositories.userRepository
            self.subjectRepository = repositories.subjectRepository
            self.subtopicRepository = repositories.subtopicRepository
            self.multipeChoiseRepository = repositories.multipleChoiceTaskRepository
            self.typingTaskRepository = repositories.typingTaskRepository
        }

        public let conn: DatabaseConnectable

        private let userRepository: UserRepository
        private let subjectRepository: SubjectRepositoring
        private let subtopicRepository: SubtopicRepositoring
        private let multipeChoiseRepository: MultipleChoiseTaskRepository
        private let typingTaskRepository: FlashCardTaskRepository
    }
}

extension Topic.DatabaseRepository: TopicRepository {

    public func deleteModelWith(id: Int, by user: User?) throws -> EventLoopFuture<Void> {
        deleteDatabase(Topic.DatabaseModel.self, modelID: id)
    }

    public func updateModelWith(id: Int, to data: Topic.Update.Data, by user: User) throws -> EventLoopFuture<Topic> {
        updateDatabase(Topic.DatabaseModel.self, modelID: id, to: data)
    }

    public func all() throws -> EventLoopFuture<[Topic]> { all(Topic.DatabaseModel.self) }
    public func find(_ id: Int) -> EventLoopFuture<Topic?> { findDatabaseModel(Topic.DatabaseModel.self, withID: id) }
    public func find(_ id: Int, or error: Error) -> EventLoopFuture<Topic> { findDatabaseModel(Topic.DatabaseModel.self, withID: id, or: error) }

    public func create(from content: Topic.Create.Data, by user: User?) throws -> EventLoopFuture<Topic.Create.Response> {

        guard let user = user else { throw Abort(.forbidden) }

        return try userRepository
            .isModerator(user: user, subjectID: content.subjectID)
            .flatMap { _ in

                self.subjectRepository
                    .find(content.subjectID, or: Abort(.badRequest))
                    .flatMap { subject in

                        try Topic.DatabaseModel(content: content, subject: subject, creator: user)
                            .create(on: self.conn)
                            .flatMap { topic in
                                try Subtopic.DatabaseModel(
                                    name: "Generelt",
                                    topicID: topic.requireID()
                                )
                                .save(on: self.conn)
                                .map { _ in try topic.content() }
                        }
                }
        }
    }

    public func numberOfTasks(in topic: Topic) throws -> EventLoopFuture<Int> {
        return Task.query(on: conn)
            .join(\Subtopic.DatabaseModel.id, to: \Task.subtopic)
            .filter(\Subtopic.DatabaseModel.topicID == topic.id)
            .count()
    }

    public func tasks(in topic: Topic) throws -> EventLoopFuture<[Task]> {
        return Task.query(on: conn)
            .join(\Subtopic.DatabaseModel.id, to: \Task.subtopic)
            .filter(\Subtopic.DatabaseModel.topicID == topic.id)
            .all()
    }

    public func subtopics(in topic: Topic) throws -> EventLoopFuture<[Subtopic]> {
        return try subtopicRepository
            .getSubtopics(in: topic)
    }

    public func subtopics(with topicID: Topic.ID) -> EventLoopFuture<[Subtopic]> {
        return subtopicRepository
            .subtopics(with: topicID)
    }

    public func content(for topic: Topic) throws -> EventLoopFuture<Topic> {
        return try subtopics(in: topic)
            .map { _ in
                // FIXME: - Should also return subtopics
                topic
//                Topic(topic: .init(topic: topic), subtopics: subtopics.map { .init(subtopic: $0) })
        }
    }

    public func getAll() -> EventLoopFuture<[Topic]> {
        return Topic.DatabaseModel.query(on: conn)
            .all()
            .map { try $0.map { try $0.content() } }
    }

    public func getTopics(in subject: Subject) throws -> EventLoopFuture<[Topic]> {
        return Topic.DatabaseModel.query(on: conn)
            .filter(\.subjectId == subject.id)
            .sort(\.chapter, .ascending)
            .all()
            .map { try $0.map { try $0.content() }}
    }

    public func getTopicsWithTaskCount(in subject: Subject) throws -> EventLoopFuture<[Topic.WithTaskCount]> {

        conn.databaseConnection(to: .psql)
            .flatMap { psqlConn in
                psqlConn.select()
                    .all(table: Topic.DatabaseModel.self)
                    .from(Topic.DatabaseModel.self)
                    .column(.count(\Task.id), as: "taskCount")
                    .join(\Topic.DatabaseModel.id, to: \Subtopic.DatabaseModel.topicID)
                    .join(\Subtopic.DatabaseModel.id, to: \Task.subtopicID)
                    .groupBy(\Topic.DatabaseModel.id)
                    .where(\Topic.DatabaseModel.subjectId == subject.id)
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

    public func getTopicResponses(in subject: Subject) throws -> EventLoopFuture<[Topic]> {
        return try getTopics(in: subject)
            .flatMap { topics in
                try topics.map {
                    try self.content(for: $0)
                }
                .flatten(on: self.conn)
        }
    }

    public func getTopic(for task: Task) -> EventLoopFuture<Topic> {
        return Topic.DatabaseModel.query(on: conn)
            .join(\Subtopic.DatabaseModel.topicID, to: \Topic.DatabaseModel.id)
            .filter(\Subtopic.DatabaseModel.id == task.subtopicID)
            .first()
            .unwrap(or: Abort(.internalServerError))
            .map { try $0.content() }
    }

    public func timelyTopics(limit: Int? = 4, on conn: PostgreSQLConnection) throws -> EventLoopFuture<[TimelyTopic]> {

        return conn.select()
            .column(\Subject.DatabaseModel.name, as: "subjectName")
            .column(\Topic.DatabaseModel.name, as: "topicName")
            .column(\Topic.DatabaseModel.id, as: "topicID")
            .column(.count(\Task.id), as: "numberOfTasks")
            .from(Subject.DatabaseModel.self)
            .join(\Subject.DatabaseModel.id, to: \Topic.DatabaseModel.subjectId)
            .join(\Topic.DatabaseModel.id, to: \Subtopic.DatabaseModel.topicID, method: .left)
            .join(\Subtopic.DatabaseModel.id, to: \Task.subtopicID, method: .left)
            .where(\Task.deletedAt == nil)
            .groupBy(\Topic.DatabaseModel.id)
            .groupBy(\Subject.DatabaseModel.id)
            .limit(limit)
            .all(decoding: TimelyTopic.self)
    }

    public func exportTopics(in subject: Subject) throws -> EventLoopFuture<SubjectExportContent> {
        return try getTopics(in: subject)
            .flatMap { topics in
                try topics.map { try self.exportTasks(in: $0) }
                    .flatten(on: self.conn)
        }.map { topicContent in
            SubjectExportContent(subject: subject, topics: topicContent)
        }
    }

    public func exportTasks(in topic: Topic) throws -> EventLoopFuture<TopicExportContent> {
        return Subtopic.DatabaseModel.query(on: conn)
            .filter(\.topicID == topic.id)
            .all()
            .flatMap { subtopics in
                try subtopics.map {
                    try self.exportTasks(in: $0.content())
                }
                .flatten(on: self.conn)
                .map { subtopicContent in
                    TopicExportContent(
                        topic: topic,
                        subtopics: subtopicContent
                    )
                }
        }
    }

    public func exportTasks(in subtopic: Subtopic) throws -> EventLoopFuture<SubtopicExportContent> {
        return conn.databaseConnection(to: .psql)
            .flatMap { psqlConn in

                psqlConn.select()
                    .all(table: Task.self)
                    .all(table: MultipleChoiceTask.DatabaseModel.self)
                    .all(table: MultipleChoiseTaskChoise.self)
                    .column(\TaskSolution.DatabaseModel.solution, as: "solution")
                    .from(Task.self)
                    .join(\Task.id, to: \MultipleChoiceTask.DatabaseModel.id, method: .left)
                    .join(\Task.id, to: \FlashCardTask.id, method: .left)
                    .join(\MultipleChoiceTask.DatabaseModel.id, to: \MultipleChoiseTaskChoise.taskId, method: .left)
                    .join(\Task.id, to: \TaskSolution.DatabaseModel.taskID, method: .left)
                    .where(\Task.subtopicID == subtopic.id)
                    .all(decoding: Task.BetaFormat.self, MultipleChoiceTask.DatabaseModel?.self, MultipleChoiseTaskChoise?.self)
                    .map { tasks in

                        var multipleTasks = [Int: MultipleChoiceTask.BetaFormat]()
                        var flashTasks = [Task.BetaFormat]()

                        for task in tasks {
                            if
                                let multiple = task.1,
                                let choise = task.2
                            {
                                if let earlierTask = multipleTasks[multiple.id ?? 0] {
                                    multipleTasks[multiple.id ?? 0] = MultipleChoiceTask.BetaFormat(
                                        task: task.0,
                                        choises: earlierTask.choises + [choise],
                                        isMultipleSelect: multiple.isMultipleSelect
                                    )
                                } else {
                                    multipleTasks[multiple.id ?? 0] = MultipleChoiceTask.BetaFormat(
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

    public func importContent(from content: TopicExportContent, in subject: Subject) throws -> EventLoopFuture<Void> {
        try Topic.DatabaseModel(
            name: content.topic.name,
            chapter: content.topic.chapter,
            subjectId: subject.id
        )
            .create(on: conn)
            .flatMap { topic in
                try content.subtopics.map {
                    try self.importContent(from: $0, in: topic.content())
                }
                .flatten(on: self.conn)
        }.transform(to: ())
    }

    public func importContent(from content: SubtopicExportContent, in topic: Topic) throws -> EventLoopFuture<Void> {

//        content.subtopic.id = nil
//        content.subtopic.topicId = try topic.requireID()

        return Subtopic.DatabaseModel(
            name: content.subtopic.name,
            topicID: content.subtopic.topicID
            )
            .create(on: conn)
            .flatMap { subtopic in
                try content.multipleChoiseTasks
                    .map { task in
                        try self
                            .multipeChoiseRepository
                            .importTask(from: task, in: subtopic.content())
                }
                .flatten(on: self.conn)
                .flatMap { _ in
                    try content.flashCards
                    .map { task in
                        try self
                            .typingTaskRepository
                            .importTask(from: task, in: subtopic.content())
                    }
                    .flatten(on: self.conn)
                }
        }.transform(to: ())
    }

//    public static func leveledTopics(in subject: Subject, ) throws -> EventLoopFuture<[[Topic]]> {
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

//    static func topicPreknowleged(in subject: Subject, ) throws -> EventLoopFuture<[Topic.Pivot.Preknowleged]> {
//        throw Abort(.internalServerError)
//        return try Topic.Pivot.Preknowleged.query(on: conn)
//            .join(\Topic.id, to: \Topic.Pivot.Preknowleged.topicID)
//            .filter(\Topic.subjectId == subject.requireID())
//            .all()
//    }

//    func structure(_ topics: [Topic], with preknowleged: [Topic.Pivot.Preknowleged]) -> [[Topic]] {
//        var knowlegedGraph = [Topic.ID: [Topic.ID]]()
//        for knowleged in preknowleged {
//            if let value = knowlegedGraph[knowleged.topicID] {
//                knowlegedGraph[knowleged.topicID] = value + [knowleged.preknowlegedID]
//            } else {
//                knowlegedGraph[knowleged.topicID] = [knowleged.preknowlegedID]
//            }
//        }
//        var levels = [Topic.ID: Int]()
//        var unleveledTopics = topics
//        var topicIndex = unleveledTopics.count - 1
//        while topicIndex >= 0 {
//            let currentTopic = unleveledTopics[topicIndex]
//            guard let currentTopicID = try? currentTopic.id else {
//                unleveledTopics.remove(at: topicIndex)
//                topicIndex -= 1
//                continue
//            }
//            if let node = knowlegedGraph[currentTopicID] {
//                let preLevels = node.compactMap { levels[$0] }
//                if preLevels.count == node.count {
//                    levels[currentTopicID] = preLevels.reduce(1) { max($0, $1) } + 1
//                    unleveledTopics.remove(at: topicIndex)
//                }
//            } else {
//                unleveledTopics.remove(at: topicIndex)
//                levels[currentTopicID] = 1
//            }
//
//            if topicIndex >= 1 {
//                topicIndex -= 1
//            } else {
//                topicIndex = unleveledTopics.count - 1
//            }
//        }
//        var leveledTopics = [[Topic]]()
//        for (topicID, level) in levels.sorted(by: { $0.1 < $1.1 }) {
//            if leveledTopics.count < level {
//                leveledTopics.append([])
//            }
//            if let topic = topics.first(where: { $0.id == topicID }) {
//                leveledTopics[level - 1] = leveledTopics[level - 1] + [topic]
//            }
//        }
//        return leveledTopics.map { level in level.sorted(by: { $0.chapter < $1.chapter }) }
//    }
}

public struct SubtopicExportContent: Content {
    let subtopic: Subtopic
    let multipleChoiseTasks: [MultipleChoiceTask.BetaFormat]
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

extension MultipleChoiceTask {
    public struct BetaFormat: Content {

        let task: Task.BetaFormat

        let choises: [MultipleChoiseTaskChoise]

        let isMultipleSelect: Bool
    }
}
