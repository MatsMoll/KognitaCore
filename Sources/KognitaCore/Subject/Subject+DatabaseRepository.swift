//
//  Subject+DatabaseRepository.swift
//  KognitaCore
//
//  Created by Mats Mollestad on 23/12/2019.
//

import Vapor
import FluentPostgreSQL
import FluentSQL

extension String {

    func removeCharacters(from forbiddenChars: CharacterSet) -> String {
        let passed = self.unicodeScalars.filter { !forbiddenChars.contains($0) }
        return String(String.UnicodeScalarView(passed))
    }

    func removeCharacters(from: String) -> String {
        return removeCharacters(from: CharacterSet(charactersIn: from))
    }

    func keepCharacetrs(in charset: CharacterSet) -> String {
        let passed = self.unicodeScalars.filter { charset.contains($0) }
        return String(String.UnicodeScalarView(passed))
    }
}

extension Subject {
    public struct DatabaseRepository: SubjectRepositoring, DatabaseConnectableRepository {

        typealias DatabaseModel = Subject.DatabaseModel

        public let conn: DatabaseConnectable

        private var userRepository: some UserRepository { User.DatabaseRepository(conn: conn) }
        private var topicRepository: some TopicRepository { Topic.DatabaseRepository(conn: conn) }
        private var subtopicRepository: some SubtopicRepositoring { Subtopic.DatabaseRepository(conn: conn) }
        private var multipleChoiseRepository: some MultipleChoiseTaskRepository { MultipleChoiceTask.DatabaseRepository(conn: conn) }
    }
}

extension Subject.DatabaseRepository {

    public func create(from content: Subject.Create.Data, by user: User?) throws -> EventLoopFuture<Subject> {
        guard let user = user, user.isAdmin else {
            throw Abort(.forbidden)
        }
        return try Subject.DatabaseModel(content: content, creator: user)
            .create(on: conn)
            .flatMap { subject in

                try User.ModeratorPrivilege(userID: user.id, subjectID: subject.requireID())
                    .create(on: self.conn)
                    .map { _ in try subject.content() }
        }
    }

    public func delete(model: Subject, by user: User?) throws -> EventLoopFuture<Void> {
        deleteDatabase(Subject.DatabaseModel.self, model: model)
    }

    public func update(model: Subject, to data: Subject.Update.Data, by user: User) throws -> EventLoopFuture<Subject> {
        updateDatabase(Subject.DatabaseModel.self, model: model, to: data)
    }

    public func all() throws -> EventLoopFuture<[Subject]> { all(Subject.DatabaseModel.self) }
    public func find(_ id: Int) -> EventLoopFuture<Subject?> { findDatabaseModel(Subject.DatabaseModel.self, withID: id) }
    public func find(_ id: Int, or error: Error) -> EventLoopFuture<Subject> { findDatabaseModel(Subject.DatabaseModel.self, withID: id, or: error) }

    /// Fetches the subject for a given topic
    /// - Parameters:
    ///   - topicID: The topic id
    ///   - conn: The database connection
    /// - Returns: A future `Subject`
    public func subjectFor(topicID: Topic.ID) -> EventLoopFuture<Subject> {
        Topic.DatabaseModel.query(on: conn)
            .filter(\.id == topicID)
            .join(\Subject.DatabaseModel.id, to: \Topic.DatabaseModel.subjectId)
            .decode(Subject.DatabaseModel.self)
            .first()
            .unwrap(or: Abort(.badRequest))
            .map { try $0.content() }
    }

    public func subject(for session: PracticeSessionRepresentable) -> EventLoopFuture<Subject> {
        PracticeSession.DatabaseModel.query(on: conn)
            .join(\PracticeSession.Pivot.Subtopic.sessionID, to: \PracticeSession.DatabaseModel.id)
            .join(\Subtopic.DatabaseModel.id, to: \PracticeSession.Pivot.Subtopic.subtopicID)
            .join(\Topic.DatabaseModel.id, to: \Subtopic.DatabaseModel.topicID)
            .join(\Subject.DatabaseModel.id, to: \Topic.DatabaseModel.subjectId)
            .filter(\PracticeSession.DatabaseModel.id == session.id)
            .decode(data: Subject.self, Subject.DatabaseModel.tableName)
            .first()
            .unwrap(or: Abort(.internalServerError))
    }

    public func getSubjectWith(id: Subject.ID) -> EventLoopFuture<Subject> {
        return Subject.DatabaseModel
            .find(id, on: conn)
            .unwrap(or: Abort(.badRequest))
            .map { try $0.content() }
    }

    public func getSubject(in topic: Topic) -> EventLoopFuture<Subject> {
        Subject.DatabaseModel.query(on: conn)
            .filter(\Subject.DatabaseModel.id == topic.subjectID)
            .first()
            .unwrap(or: Abort(.badRequest))
            .map { try $0.content() }
    }

    public func importContent(_ content: SubjectExportContent) -> EventLoopFuture<Subject> {
        return conn.transaction(on: .psql) { conn in
            try Subject.DatabaseModel(
                name: content.subject.name,
                category: content.subject.category,
                description: content.subject.description,
                creatorId: 1
                )
                .create(on: conn)
                .flatMap { subject in
                    try content.topics.map { try self.topicRepository.importContent(from: $0, in: subject.content()) }
                        .flatten(on: conn)
                        .map { try subject.content() }
            }
        }
    }

    public func importContent(in subject: Subject, peerWise: [Task.PeerWise], user: User) throws -> EventLoopFuture<Void> {

        let knownTopic = peerWise.filter({ $0.topicName != "" })

        return Topic.DatabaseModel.query(on: conn)
            .filter(\.subjectId == subject.id)
            .count()
            .flatMap { numberOfExistingTopics in

                var numberOfTopics = numberOfExistingTopics

                return try knownTopic
                    .group(by: \.topicName)
                    .map { topicName, tasks in

                        numberOfTopics += 1

                        return try self.topicRepository.create(
                            from: Topic.Create.Data(
                                subjectID: subject.id,
                                name: topicName,
                                chapter: numberOfTopics
                            ),
                            by: user
                        )
                            .flatMap { topic in
                                try self.subtopicRepository
                                    .getSubtopics(in: topic)
                                    .flatMap { subtopics in

                                        guard let subtopic = subtopics.first else { throw Abort(.internalServerError) }

                                        return try tasks.map { task in
                                            try self.multipleChoiseRepository.create(
                                                from: MultipleChoiceTask.Create.Data(
                                                    subtopicId: subtopic.id,
                                                    description: nil,
                                                    question: task.question,
                                                    solution: task.solution,
                                                    isMultipleSelect: false,
                                                    examPaperSemester: nil,
                                                    examPaperYear: nil,
                                                    isTestable: false,
                                                    choises: task.choises
                                                ),
                                                by: user
                                            )
                                                .transform(to: ())
                                        }
                                        .flatten(on: self.conn)
                                }
                        }
                }
                .flatten(on: self.conn)
                .transform(to: ())
        }
    }

    public func allActive(for user: User) throws -> EventLoopFuture<[Subject]> {

        return Subject.DatabaseModel.query(on: conn)
            .join(\User.ActiveSubject.subjectID, to: \Subject.DatabaseModel.id, method: .left)
            .filter(\User.ActiveSubject.userID == user.id)
            .decode(Subject.DatabaseModel.self)
            .all()
            .map { try $0.map { try $0.content() } }
    }

    struct SubjectID: Decodable {
        let subjectId: Subject.ID
    }

    public func subjectIDFor(taskIDs: [Task.ID]) -> EventLoopFuture<Subject.ID> {

        return conn.databaseConnection(to: .psql)
            .flatMap { conn in

                conn.select()
                    .column(\Topic.DatabaseModel.subjectId)
                    .from(Task.self)
                    .join(\Task.subtopicID, to: \Subtopic.DatabaseModel.id)
                    .join(\Subtopic.DatabaseModel.topicID, to: \Topic.DatabaseModel.id)
                    .where(\Task.id, .in, taskIDs)
                    .groupBy(\Topic.DatabaseModel.subjectId)
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

    public func subjectIDFor(topicIDs: [Topic.ID]) -> EventLoopFuture<Subject.ID> {

        return conn.databaseConnection(to: .psql)
            .flatMap { conn in

                conn.select()
                    .column(\Topic.DatabaseModel.subjectId)
                    .from(Topic.DatabaseModel.self)
                    .where(\Topic.DatabaseModel.id, .in, topicIDs)
                    .groupBy(\Topic.DatabaseModel.subjectId)
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

    public func subjectIDFor(subtopicIDs: [Subtopic.ID]) -> EventLoopFuture<Subject.ID> {

        return conn.databaseConnection(to: .psql)
            .flatMap { conn in

                conn.select()
                    .column(\Topic.DatabaseModel.subjectId)
                    .from(Subtopic.DatabaseModel.self)
                    .join(\Subtopic.DatabaseModel.topicID, to: \Topic.DatabaseModel.id)
                    .where(\Subtopic.DatabaseModel.id, .in, subtopicIDs)
                    .groupBy(\Topic.DatabaseModel.subjectId)
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

    public func mark(inactive subject: Subject, for user: User) throws -> EventLoopFuture<Void> {

        User.ActiveSubject.query(on: conn)
            .filter(\User.ActiveSubject.subjectID == subject.id)
            .filter(\User.ActiveSubject.userID == user.id)
            .first()
            .unwrap(or: Abort(.badRequest))
            .delete(on: conn)
            .transform(to: ())
    }

    public func mark(active subject: Subject, canPractice: Bool, for user: User) throws -> EventLoopFuture<Void> {
        User.ActiveSubject(
            userID: user.id,
            subjectID: subject.id,
            canPractice: canPractice
        )
            .create(on: conn)
            .transform(to: ())
    }

    public func grantModeratorPrivilege(for userID: User.ID, in subjectID: Subject.ID, by moderator: User) throws -> EventLoopFuture<Void> {

        try userRepository
            .isModerator(user: moderator, subjectID: subjectID)
            .flatMap {
                User.ModeratorPrivilege(
                    userID: userID,
                    subjectID: subjectID
                )
                    .create(on: self.conn)
                    .transform(to: ())
        }
    }

    public func revokeModeratorPrivilege(for userID: User.ID, in subjectID: Subject.ID, by moderator: User) throws -> EventLoopFuture<Void> {
        guard moderator.id != userID else {
            throw Abort(.badRequest)
        }
        return try userRepository
            .isModerator(user: moderator, subjectID: subjectID)
            .flatMap {

                User.ModeratorPrivilege.query(on: self.conn)
                    .filter(\.userID == userID)
                    .filter(\.subjectID == subjectID)
                    .first()
                    .unwrap(or: Abort(.badRequest))
                    .flatMap { privilege in

                        privilege.delete(on: self.conn)
                }
        }
    }

    public func active(subject: Subject, for user: User) throws -> EventLoopFuture<User.ActiveSubject?> {

        User.ActiveSubject.query(on: conn)
            .filter(\.userID == user.id)
            .filter(\.subjectID == subject.id)
            .first()
    }

    struct ActiveSubjectQuery: Codable {
        let canPractice: Bool
    }

    public func allSubjects(for user: User) throws -> EventLoopFuture<[Subject.ListOverview]> {

        return Subject.DatabaseModel.query(on: conn)
            .all()
            .flatMap { subjects in

                User.ActiveSubject.query(on: self.conn)
                    .filter(\.userID == user.id)
                    .all()
                    .map { activeSubjects in

                        subjects.map { subject in
                            Subject.ListOverview(
                                subject: subject,
                                isActive: activeSubjects.contains(where: { $0.subjectID == subject.id })
                            )
                        }
                }
        }
    }

    struct CompendiumData: Decodable {
        let question: String
        let solution: String
        let topicName: String
        let topicChapter: Int
        let topicID: Topic.ID
        let subtopicName: String
        let subtopicID: Subtopic.ID
    }

    public func compendium(for subjectID: Subject.ID, filter: SubjectCompendiumFilter) throws -> EventLoopFuture<Subject.Compendium> {

        return conn.databaseConnection(to: .psql)
            .flatMap { conn in

                Subject.DatabaseModel.find(subjectID, on: conn)
                    .unwrap(or: Abort(.badRequest))
                    .flatMap { subject in

                        var query = conn.select()
                            .column(\Task.question)
                            .column(\TaskSolution.DatabaseModel.solution)
                            .column(\Topic.DatabaseModel.name, as: "topicName")
                            .column(\Topic.DatabaseModel.id, as: "topicID")
                            .column(\Topic.DatabaseModel.chapter, as: "topicChapter")
                            .column(\Subtopic.DatabaseModel.name, as: "subtopicName")
                            .column(\Subtopic.DatabaseModel.id, as: "subtopicID")
                            .from(Task.self)
                            .join(\Task.subtopicID, to: \Subtopic.DatabaseModel.id)
                            .join(\Subtopic.DatabaseModel.topicID, to: \Topic.DatabaseModel.id)
                            .join(\Task.id, to: \FlashCardTask.id) // Only flash card tasks
                            .join(\Task.id, to: \TaskSolution.DatabaseModel.taskID)
                            .where(\Task.description == nil)
                            .where(\Task.deletedAt == nil)
                            .where(\Topic.DatabaseModel.subjectId == subjectID)

                        if let subtopicIDs = filter.subtopicIDs {
                            query = query.where(\Subtopic.DatabaseModel.id, .in, Array(subtopicIDs))
                        }

                        return query
                            .all(decoding: CompendiumData.self)
                            .map { data in

                                Subject.Compendium(
                                    subjectID: subjectID,
                                    subjectName: subject.name,
                                    topics: data.group(by: \.topicID)
                                        .map { _, topicData in

                                            Subject.Compendium.TopicData(
                                                name: topicData.first!.topicName,
                                                chapter: topicData.first!.topicChapter,
                                                subtopics: topicData.group(by: \.subtopicID)
                                                    .map { subtopicID, questions in

                                                        Subject.Compendium.SubtopicData(
                                                            subjectID: subjectID,
                                                            subtopicID: subtopicID,
                                                            name: questions.first!.subtopicName,
                                                            questions: questions.map { question in

                                                                Subject.Compendium.QuestionData(
                                                                    question: question.question,
                                                                    solution: question.solution
                                                                )
                                                            }
                                                        )
                                                }
                                            )
                                    }
                                    .sorted(by: { $0.chapter < $1.chapter })
                                )
                        }
                }
        }
    }
}

extension Subject.ListOverview {
    init(subject: Subject.DatabaseModel, isActive: Bool) {
        self.init(
            id: subject.id ?? 0,
            name: subject.name,
            description: subject.description,
            category: subject.category,
            isActive: isActive
        )
    }
}

extension Subject {
    public struct Compendium: Content {

        public struct QuestionData: Codable {
            public let question: String
            public let solution: String
        }

        public struct SubtopicData: Codable {
            public let subjectID: Subject.ID
            public let subtopicID: Subtopic.ID
            public let name: String
            public let questions: [QuestionData]
        }

        public struct TopicData: Codable {
            public let name: String
            public let chapter: Int
            public let subtopics: [SubtopicData]
        }

        public let subjectID: Subject.ID
        public let subjectName: String
        public let topics: [TopicData]
    }
}

extension TaskSolution {

    public struct Unverified: Codable {

        public let taskID: Task.ID
        public let solutionID: TaskSolution.ID
        public let description: String?
        public let question: String
        public let solution: String

        public let choises: [MultipleChoiceTaskChoice]

        init(task: Task, solution: TaskSolution, choises: [MultipleChoiseTaskChoise]) throws {
            self.taskID = try task.requireID()
            self.solutionID = solution.id
            self.description = task.description
            self.question = task.question
            self.solution = solution.solution
            self.choises = try choises.map { try .init(choice: $0) }
        }
    }
}

extension MultipleChoiceTaskChoice {
    init(choice: MultipleChoiseTaskChoise) throws {
        try self.init(
            id: choice.requireID(),
            choise: choice.choise,
            isCorrect: choice.isCorrect
        )
    }
}
