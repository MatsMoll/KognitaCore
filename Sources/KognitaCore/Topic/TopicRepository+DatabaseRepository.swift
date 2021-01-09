//
//  TopicRepository+DatabaseRepository.swift
//  KognitaCore
//
//  Created by Mats Mollestad on 14/11/2020.
//

import Vapor
import FluentKit
import FluentSQL
import PostgresKit

extension Topic {
    /// A Database implementatino of a `TopicRepository`
    public struct DatabaseRepository: DatabaseConnectableRepository {

        init(database: Database, repositories: RepositoriesRepresentable, logger: Logger) {
            self.database = database
            self.repositories = repositories
            self.logger = logger
        }

        /// The database to connect to
        public let database: Database

        /// A logger to use
        public let logger: Logger

        /// The other repositories to use
        private let repositories: RepositoriesRepresentable

        /// The user repository to use
        private var userRepository: UserRepository { repositories.userRepository }

        /// The subtopic repository to use
        private var subtopicRepository: SubtopicRepositoring { repositories.subtopicRepository }

        /// The multiple choice task repository to use
        private var multipeChoiseRepository: MultipleChoiseTaskRepository { repositories.multipleChoiceTaskRepository }

        /// The typing task repository to use
        private var typingTaskRepository: TypingTaskRepository { repositories.typingTaskRepository }

        /// The term repository
        private var termRepository: TermRepository { repositories.termRepository }
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

    public func exportTopics(in subject: Subject) throws -> EventLoopFuture<Subject.Export> {
        return getTopicsWith(subjectID: subject.id)
            .failableFlatMap { topics in
                try topics.map { try self.exportTasks(in: $0) }
                    .flatten(on: self.database.eventLoop)
        }.map { topicContent in
            Subject.Export(subject: subject, topics: topicContent, resources: [])
        }
    }

    public func exportTasks(in topic: Topic) throws -> EventLoopFuture<Topic.Export> {
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
                Topic.Export(
                    topic: topic,
                    subtopics: subtopicContent
                )
        }
    }

    public func exportTasks(in subtopic: Subtopic) throws -> EventLoopFuture<Subtopic.Export> {

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
                            .flatMapThrowing { choices in

                                var multipleTasks = [Int: MultipleChoiceTask.Details]()
                                var typingTask = [TypingTask.Details]()

                                try tasks.forEach { task, multiple in
                                    guard let id = task.id else { return }

                                    let taskSolutions = solutions.filter({ $0.$task.id == id }).compactMap { try? $0.content() }

                                    if let multiple = multiple {
                                        multipleTasks[id] = MultipleChoiceTask.Details(
                                            task: try task.content(),
                                            choices: choices.filter { $0.$task.id == id }.compactMap { try? $0.content() },
                                            isMultipleSelect: multiple.isMultipleSelect,
                                            solutions: taskSolutions
                                        )
                                    } else {
                                        typingTask.append(
                                            TypingTask.Details(
                                                task: try task.content(),
                                                solutions: taskSolutions
                                            )
                                        )
                                    }
                                }

                                return Subtopic.Export(
                                    subtopic: subtopic,
                                    multipleChoiceTasks: multipleTasks.map { $0.value },
                                    typingTasks: typingTask
                                )
                        }
                }
        }
    }

    public func importContent(from content: Topic.Import, in subjectID: Subject.ID, resourceMap: [Resource.ID: Resource.ID]) -> EventLoopFuture<Void> {
        do {
            let topic = try Topic.DatabaseModel(
                name: content.topic.name,
                chapter: content.topic.chapter,
                subjectId: subjectID
            )
            logger.info("Importing topic for: \(subjectID)")
            return handle(exams: content.exams, subjectID: subjectID)
                .flatMap { _ in
                    topic.create(on: database)
                        .failableFlatMap {
                            try content.subtopics.map {
                                try importContent(from: $0, in: topic.content(), resourceMap: resourceMap)
                            }
                            .flatten(on: database.eventLoop)
                    }.transform(to: ())
            }
        } catch {
            return database.eventLoop.future(error: error)
        }
    }

    public func importContent(from content: Subtopic.Import, in topic: Topic, resourceMap: [Resource.ID: Resource.ID]) throws -> EventLoopFuture<Void> {

//        content.subtopic.id = nil
//        content.subtopic.topicId = try topic.requireID()

        let subtopic = Subtopic.DatabaseModel(
            name: content.subtopic.name,
            topicID: topic.id
        )

        logger.info("Importing subtopic for: \(topic.id)")

        let exams = Set(content.multipleChoiceTasks.compactMap(\.exam) + content.typingTasks.compactMap(\.exam))

        return handle(exams: exams, subjectID: topic.subjectID)
            .flatMap { examIDs in
                subtopic.create(on: database)
                    .failableFlatMap {
                        try content.multipleChoiceTasks
                            .map { task in
                                try multipeChoiseRepository
                                    .importTask(from: task, in: subtopic.content(), examID: task.exam == nil ? nil : examIDs[task.exam!], resourceMap: resourceMap)
                        }
                        .flatten(on: database.eventLoop)
                }
                .failableFlatMap {
                    try content.typingTasks
                        .map { task in
                            try typingTaskRepository
                                .importTask(from: task, in: subtopic.content(), examID: task.exam == nil ? nil : examIDs[task.exam!], resourceMap: resourceMap)
                    }
                    .flatten(on: database.eventLoop)
                }
                .failableFlatMap {
                    let subtopicID = try subtopic.requireID()
                    var existingTerms = Set<String>()
                    return content.terms.filter { term in
                        if existingTerms.contains(term.term) {
                            return false
                        } else {
                            existingTerms.insert(term.term)
                            return true
                        }
                    }.map { term in
                        termRepository.importContent(term: term, for: subtopicID, resourceMap: resourceMap)
                    }
                    .flatten(on: database.eventLoop)
                    .transform(to: subtopicID)
                }
                .flatMap { subtopicID in
                    termRepository.allWith(subtopicID: subtopicID)
                        .flatMap { terms in
                            termRepository.generateMultipleChoiceTasksWith(termIDs: Set(terms.map { $0.id }), toSubtopicID: subtopicID)
                    }
                }
            }
    }

    private func handle(exams: Set<Exam.Compact>, subjectID: Subject.ID) -> EventLoopFuture<[Exam.Compact: Exam.ID]> {

        var examIDs = [Exam.Compact: Exam.ID]()

        return exams.map { exam in
            repositories.examRepository
                .findExamWith(subjectID: subjectID, year: exam.year, type: exam.type)
                .flatMap { savedExam in
                    if let saved = savedExam {
                        examIDs[exam] = saved.id
                        return database.eventLoop.future()
                    } else {
                        return repositories.examRepository.create(
                            from: Exam.Create.Data(subjectID: subjectID, type: exam.type, year: exam.year)
                        )
                        .map { examIDs[exam] = $0.id }
                        .transform(to: ())
                    }
                }
        }
        .flatten(on: database.eventLoop)
        .transform(to: examIDs)
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

                        savedTopics
                            .filter { topicIDs.contains($0.id ?? 0) == false }
                            .map { $0.delete(on: self.database) }
                            .flatten(on: database.eventLoop)
                            .transform(to: savedTopics)
                    }
                    .flatMap { savedTopics in
                        savedTopics
                            .filter { (topic: Topic.DatabaseModel) in topicIDs.contains(topic.id ?? 0) }
                            .compactMap { (topicToUpdate: Topic.DatabaseModel) -> EventLoopFuture<Void>? in
                                guard let topic = topics.first(where: { $0.id == topicToUpdate.id }) else {
                                    return nil
                                }
                                topicToUpdate.chapter = topic.chapter
                                topicToUpdate.name = topic.name
                                return topicToUpdate.update(on: database)
                            }
                            .flatten(on: database.eventLoop)
                    }
                    .flatMap {
                        newTopics.compactMap { topic in
                            try? self.create(from: Topic.Create.Data(subjectID: subjectID, name: topic.name, chapter: topic.chapter), by: user)
                                .transform(to: ())
                        }
                        .flatten(on: database.eventLoop)
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
