//
//  TopicRepository.swift
//  KognitaCore
//
//  Created by Mats Mollestad on 10/04/2019.
//

import Vapor
import FluentKit
import FluentSQL

public protocol TopicRepository: DeleteModelRepository {
    func all() throws -> EventLoopFuture<[Topic]>
    func find(_ id: Topic.ID, or error: Error) -> EventLoopFuture<Topic>
    func create(from content: Topic.Create.Data, by user: User?) throws -> EventLoopFuture<Topic.Create.Response>
    func updateModelWith(id: Int, to data: Topic.Update.Data, by user: User) throws -> EventLoopFuture<Topic.Update.Response>
    func getTopicsWith(subjectID: Subject.ID) -> EventLoopFuture<[Topic]>
    func exportTasks(in topic: Topic) throws -> EventLoopFuture<TopicExportContent>
    func exportTopics(in subject: Subject) throws -> EventLoopFuture<SubjectExportContent>
    func getTopicResponses(in subject: Subject) throws -> EventLoopFuture<[Topic]>
    func importContent(from content: TopicExportContent, in subject: Subject) throws -> EventLoopFuture<Void>
    func importContent(from content: SubtopicExportContent, in topic: Topic) throws -> EventLoopFuture<Void>
    func getTopicsWithTaskCount(withSubjectID subjectID: Subject.ID) throws -> EventLoopFuture<[Topic.WithTaskCount]>
    func topicFor(taskID: Task.ID) -> EventLoopFuture<Topic>
    func topicsWithSubtopics(subjectID: Subject.ID) -> EventLoopFuture<[Topic.WithSubtopics]>
    func save(topics: [Topic], forSubjectID subjectID: Subject.ID, user: User) -> EventLoopFuture<Void>
}

public struct TimelyTopic: Codable {
    public let subjectName: String
    public let topicName: String
    public let topicID: Int
    public let numberOfTasks: Int
}

struct TopicTaskCount: Codable {
    let taskCount: Int
    let multipleChoiceTaskCount: Int
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
    public struct WithTaskCount: Content {
        public let topic: Topic

        public let typingTaskCount: Int
        public let multipleChoiceTaskCount: Int

        public var totalTaskCount: Int { typingTaskCount + multipleChoiceTaskCount }

        public func userLevelZero() -> UserLevel {
            .init(topicID: topic.id, correctScore: 0, maxScore: Double(totalTaskCount))
        }
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

    public func topicFor(taskID: Task.ID) -> EventLoopFuture<Topic> {
        TaskDatabaseModel.query(on: database)
            .join(parent: \TaskDatabaseModel.$subtopic)
            .join(parent: \Subtopic.DatabaseModel.$topic)
            .filter(\.$id == taskID)
            .first(Topic.DatabaseModel.self)
            .unwrap(or: Abort(.badRequest))
            .content()
    }

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

    public func topicsWithSubtopics(subjectID: Subject.ID) -> EventLoopFuture<[Topic.WithSubtopics]> {
        Subtopic.DatabaseModel.query(on: database)
            .join(parent: \Subtopic.DatabaseModel.$topic)
            .filter(Topic.DatabaseModel.self, \Topic.DatabaseModel.$subject.$id == subjectID)
            .sort(Topic.DatabaseModel.self, \Topic.DatabaseModel.$chapter)
            .sort(\Subtopic.DatabaseModel.$id)
            .all(with: \Subtopic.DatabaseModel.$topic)
            .map { subtopics in
                subtopics.group(by: \Subtopic.DatabaseModel.topic.name)
            }
            .flatMapEachThrowing { (topicName, subtopics) in
                try Topic.WithSubtopics(name: topicName, subtopics: subtopics.map { try $0.content() })
        }
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

    public func getTopicsWith(subjectID: Subject.ID) -> EventLoopFuture<[Topic]> {
        return Topic.DatabaseModel.query(on: database)
            .filter(\.$subject.$id == subjectID)
            .sort(\.$chapter, .ascending)
            .all()
            .flatMapEachThrowing { try $0.content() }
    }

    public func getTopicsWithTaskCount(withSubjectID subjectID: Subject.ID) -> EventLoopFuture<[Topic.WithTaskCount]> {

        guard let sql = database as? SQLDatabase else { return database.eventLoop.future(error: Abort(.internalServerError)) }
        return sql.select()
            .column(SQLColumn(SQLLiteral.all, table: SQLIdentifier(Topic.DatabaseModel.schema)))
            .count(\TaskDatabaseModel.$id, as: "taskCount")
            .count(\MultipleChoiceTask.DatabaseModel.$id, as: "multipleChoiceTaskCount")
            .from(TaskDatabaseModel.schema)
            .join(parent: \TaskDatabaseModel.$subtopic)
            .join(parent: \Subtopic.DatabaseModel.$topic)
            .join(from: \TaskDatabaseModel.$id, to: \MultipleChoiceTask.DatabaseModel.$id, method: .left)
            .groupBy(\Topic.DatabaseModel.$id)
            .where("subjectID", .equal, subjectID)
            .where("isTestable", .equal, false)
            .where(SQLColumn("deletedAt", table: TaskDatabaseModel.schema), .is, SQLLiteral.null)
            .all(decoding: Topic.self, TopicTaskCount.self)
            .map { topics in
                topics.map { data in
                    Topic.WithTaskCount(
                        topic: data.0,
                        typingTaskCount: data.1.taskCount - data.1.multipleChoiceTaskCount,
                        multipleChoiceTaskCount: data.1.multipleChoiceTaskCount
                    )
                }
                .sorted(by: { $0.topic.chapter < $1.topic.chapter })
        }
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
        return getTopicsWith(subjectID: subject.id)
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
                                            choises: choices.filter { $0.$task.id == id }.compactMap { try? $0.content() },
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
            topicID: topic.id
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

    public func save(topics: [Topic], forSubjectID subjectID: Subject.ID, user: User) -> EventLoopFuture<Void> {

        guard Set(topics.map { $0.chapter }).count == topics.count else {
            // Duplicate chapters
            return database.eventLoop.future(error: Abort(.badRequest))
        }
        let newTopics = topics.filter { $0.id < 1 }
        let topicIDs = Set(topics.map { $0.id })

        return userRepository
            .isModerator(user: user, subjectID: subjectID)
            .ifFalse(throw: Abort(.forbidden))
            .flatMap {

                Topic.DatabaseModel.query(on: self.database)
                    .filter(\Topic.DatabaseModel.$subject.$id == subjectID)
                    .all()
                    .flatMap { savedTopics in

                        let deletedTopics = savedTopics
                            .filter { topicIDs.contains($0.id ?? 0) == false }
                            .map { $0.delete(on: self.database) }

                        let updatedTopics = savedTopics
                            .filter { (topic: Topic.DatabaseModel) in topicIDs.contains(topic.id ?? 0) }
                            .compactMap { (topicToUpdate: Topic.DatabaseModel) -> EventLoopFuture<Void>? in
                                guard let topic = topics.first(where: { $0.id == topicToUpdate.id }) else {
                                    return nil
                                }
                                topicToUpdate.chapter = topic.chapter
                                topicToUpdate.name = topic.name
                                return topicToUpdate.update(on: self.database)
                        }
                        let createTopics = newTopics.compactMap { topic in
                            try? self.create(from: Topic.Create.Data(subjectID: subjectID, name: topic.name, chapter: topic.chapter), by: user)
                                .transform(to: ())
                        }

                        return (deletedTopics + updatedTopics + createTopics)
                            .flatten(on: self.database.eventLoop)
                }
        }
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

        let choises: [MultipleChoiceTaskChoice]

        let isMultipleSelect: Bool
    }
}
