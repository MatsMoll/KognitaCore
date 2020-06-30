//
//  TopicRepository.swift
//  KognitaCore
//
//  Created by Mats Mollestad on 10/04/2019.
//

import Vapor
import FluentKit

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

extension TaskBetaFormat {
    init(task: TaskDatabaseModel, solution: String?) {
        self.init(
            description: task.description,
            question: task.question,
            solution: solution,
            examPaperSemester: nil,
            examPaperYear: task.examPaperYear,
            editedTaskID: nil
        )
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

        init(database: Database, repositories: RepositoriesRepresentable) {
            self.database = database
            self.userRepository = repositories.userRepository
            self.subtopicRepository = repositories.subtopicRepository
            self.multipeChoiseRepository = repositories.multipleChoiceTaskRepository
            self.typingTaskRepository = repositories.typingTaskRepository
        }

        public let database: Database

        private let userRepository: UserRepository
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

        return userRepository
            .isModerator(user: user, subjectID: content.subjectID)
            .ifFalse(throw: Abort(.forbidden))
            .failableFlatMap {

                let topic = try Topic.DatabaseModel(content: content, creator: user)

                return topic.create(on: self.database)
                    .failableFlatMap {
                        try Subtopic.DatabaseModel(
                            name: "Generelt",
                            topicID: topic.requireID()
                        )
                        .create(on: self.database)
                        .flatMapThrowing { try topic.content() }
                }
        }
    }

    public func numberOfTasks(in topic: Topic) throws -> EventLoopFuture<Int> {
        return database.eventLoop.future(error: Abort(.notImplemented))
//        return TaskDatabaseModel.query(on: db)
//            .join(\Subtopic.DatabaseModel.id, to: \TaskDatabaseModel.subtopic)
//            .filter(\Subtopic.DatabaseModel.topicID == topic.id)
//            .count()
    }

    func tasks(in topic: Topic) throws -> EventLoopFuture<[TaskDatabaseModel]> {
        return database.eventLoop.future(error: Abort(.notImplemented))
//        return TaskDatabaseModel.query(on: conn)
//            .join(\Subtopic.DatabaseModel.id, to: \TaskDatabaseModel.subtopic)
//            .filter(\Subtopic.DatabaseModel.topicID == topic.id)
//            .all()
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
        return Topic.DatabaseModel.query(on: database)
            .all()
            .flatMapEachThrowing { try $0.content() }
    }

    public func getTopics(in subject: Subject) throws -> EventLoopFuture<[Topic]> {
        return Topic.DatabaseModel.query(on: database)
            .filter(\.$subject.$id == subject.id)
            .sort(\.$chapter, .ascending)
            .all()
            .flatMapEachThrowing { try $0.content() }
    }

    public func getTopicsWithTaskCount(in subject: Subject) throws -> EventLoopFuture<[Topic.WithTaskCount]> {

        return database.eventLoop.future(error: Abort(.notImplemented))
//        conn.databaseConnection(to: .psql)
//            .flatMap { psqlConn in
//                psqlConn.select()
//                    .all(table: Topic.DatabaseModel.self)
//                    .from(Topic.DatabaseModel.self)
//                    .column(.count(\TaskDatabaseModel.id), as: "taskCount")
//                    .join(\Topic.DatabaseModel.id, to: \Subtopic.DatabaseModel.topicID)
//                    .join(\Subtopic.DatabaseModel.id, to: \TaskDatabaseModel.subtopicID)
//                    .groupBy(\Topic.DatabaseModel.id)
//                    .where(\Topic.DatabaseModel.subjectId == subject.id)
//                    .where(\TaskDatabaseModel.isTestable == false)
//                    .all(decoding: Topic.self, TopicTaskCount.self)
//                    .map { topics in
//                        topics.map { data in
//                            Topic.WithTaskCount(
//                                topic: data.0,
//                                taskCount: data.1.taskCount
//                            )
//                        }
//                        .sorted(by: { $0.topic.chapter < $1.topic.chapter })
//            }
//        }
   }

    public func getTopicResponses(in subject: Subject) throws -> EventLoopFuture<[Topic]> {
        return database.eventLoop.future(error: Abort(.notImplemented))
//        return try getTopics(in: subject)
//            .flatMap { topics in
//                try topics.map {
//                    try self.content(for: $0)
//                }
//                .flatten(on: self.conn)
//        }
    }

    public func getTopic(for taskID: Task.ID) -> EventLoopFuture<Topic> {
        return database.eventLoop.future(error: Abort(.notImplemented))
//        return Topic.DatabaseModel.query(on: conn)
//            .join(\Subtopic.DatabaseModel.topicID, to: \Topic.DatabaseModel.id)
//            .filter(\Subtopic.DatabaseModel.id == task.subtopicID)
//            .first()
//            .unwrap(or: Abort(.internalServerError))
//            .map { try $0.content() }
    }

    public func exportTopics(in subject: Subject) throws -> EventLoopFuture<SubjectExportContent> {
        return try getTopics(in: subject)
            .failableFlatMap { topics in
                try topics.map { try self.exportTasks(in: $0) }
                    .flatten(on: self.database.eventLoop)
        }.map { topicContent in
            SubjectExportContent(subject: subject, topics: topicContent)
        }
    }

    public func exportTasks(in topic: Topic) throws -> EventLoopFuture<TopicExportContent> {
        return Subtopic.DatabaseModel.query(on: database)
            .filter(\.$topic.$id == topic.id)
            .all()
            .failableFlatMap { subtopics in
                try subtopics.map {
                    try self.exportTasks(in: $0.content())
                }
                .flatten(on: self.database.eventLoop)
            }
            .map { subtopicContent in
                TopicExportContent(
                    topic: topic,
                    subtopics: subtopicContent
                )
        }
    }

    public func exportTasks(in subtopic: Subtopic) throws -> EventLoopFuture<SubtopicExportContent> {

        return TaskDatabaseModel.query(on: database)
            .join(superclass: MultipleChoiceTask.DatabaseModel.self, with: TaskDatabaseModel.self, method: .left)
            .filter(\TaskDatabaseModel.$subtopic.$id == subtopic.id)
            .all(TaskDatabaseModel.self, MultipleChoiceTask.DatabaseModel?.self)
            .flatMap { tasks in

                TaskSolution.DatabaseModel.query(on: self.database)
                    .filter(\.$task.$id ~~ tasks.compactMap { $0.0.id })
                    .all()
                    .flatMap { solutions in

                        MultipleChoiseTaskChoise.query(on: self.database)
                            .filter(\.$task.$id ~~ tasks.compactMap { $0.1?.id })
                            .all()
                            .map { choices in

                                var multipleTasks = [Int: MultipleChoiceTask.BetaFormat]()
                                var flashTasks = [TaskBetaFormat]()

                                tasks.forEach { task, multiple in
                                    guard let id = task.id else { return }

                                    let betaTask = TaskBetaFormat(task: task, solution: solutions.first(where: { $0.$task.id == id })?.solution)

                                    if let multiple = multiple {
                                        multipleTasks[id] = MultipleChoiceTask.BetaFormat(
                                            task: betaTask,
                                            choises: choices.filter { $0.$task.id == id },
                                            isMultipleSelect: multiple.isMultipleSelect
                                        )
                                    } else {
                                        flashTasks.append(betaTask)
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
    }

    public func importContent(from content: TopicExportContent, in subject: Subject) throws -> EventLoopFuture<Void> {
        let topic = try Topic.DatabaseModel(
            name: content.topic.name,
            chapter: content.topic.chapter,
            subjectId: subject.id
        )
        return topic.create(on: database)
            .failableFlatMap {
                try content.subtopics.map {
                    try self.importContent(from: $0, in: topic.content())
                }
                .flatten(on: self.database.eventLoop)
        }.transform(to: ())
    }

    public func importContent(from content: SubtopicExportContent, in topic: Topic) throws -> EventLoopFuture<Void> {

//        content.subtopic.id = nil
//        content.subtopic.topicId = try topic.requireID()

        let subtopic = Subtopic.DatabaseModel(
            name: content.subtopic.name,
            topicID: content.subtopic.topicID
        )

        return subtopic.create(on: database)
            .failableFlatMap {
                try content.multipleChoiseTasks
                    .map { task in
                        try self
                            .multipeChoiseRepository
                            .importTask(from: task, in: subtopic.content())
                }
                .flatten(on: self.database.eventLoop)
        }
        .failableFlatMap {
            try content.flashCards
                .map { task in
                    try self
                        .typingTaskRepository
                        .importTask(from: task, in: subtopic.content())
            }
            .flatten(on: self.database.eventLoop)
        }
        .transform(to: ())
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
    let flashCards: [TaskBetaFormat]
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

        let task: TaskBetaFormat

        let choises: [MultipleChoiseTaskChoise]

        let isMultipleSelect: Bool
    }
}
