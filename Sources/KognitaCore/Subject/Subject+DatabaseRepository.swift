//
//  Subject+DatabaseRepository.swift
//  KognitaCore
//
//  Created by Mats Mollestad on 23/12/2019.
//
// swiftlint:disable large_tuple

import Vapor
import FluentSQL
import Fluent

extension EventLoopFuture where Value: Model {
    func create(on database: Database) -> EventLoopFuture<Void> {
        flatMap { $0.create(on: database) }
    }

    func update(on database: Database) -> EventLoopFuture<Void> {
        flatMap { $0.update(on: database) }
    }

    func delete(on database: Database) -> EventLoopFuture<Void> {
        flatMap { $0.delete(on: database) }
    }
}

extension QueryBuilder {
    public func all<Joined>(
        _ joined: Joined.Type
    ) -> EventLoopFuture<[Joined]>
        where
            Joined: Schema {
        let copy = self.copy()
        return copy.all().flatMapThrowing {
            try $0.map { try $0.joined(Joined.self) }
        }
    }

    public func all<Joined, JoinedTwo>(
        _ joined: Joined.Type,
        _ joinedTwo: JoinedTwo.Type
    ) -> EventLoopFuture<[(Joined, JoinedTwo)]>
        where Joined: Schema, JoinedTwo: Schema {
        let copy = self.copy()
        return copy.all().flatMapThrowing {
            try $0.map { try ($0.joined(Joined.self), $0.joined(JoinedTwo.self)) }
        }
    }

    public func all<Joined, JoinedTwo, JoinedThree>(
        _ joined: Joined.Type,
        _ joinedTwo: JoinedTwo.Type,
        _ joinedThree: JoinedThree.Type
    ) -> EventLoopFuture<[(Joined, JoinedTwo, JoinedThree)]>
        where Joined: Schema, JoinedTwo: Schema, JoinedThree: Schema {
        let copy = self.copy()
        return copy.all().flatMapThrowing {
            try $0.map { try ($0.joined(Joined.self), $0.joined(JoinedTwo.self), $0.joined(JoinedThree.self)) }
        }
    }

    public func all<Joined, JoinedTwo, JoinedThree>(
        _ joined: Joined.Type,
        _ joinedTwo: JoinedTwo.Type,
        _ joinedThree: Optional<JoinedThree>.Type
    ) -> EventLoopFuture<[(Joined, JoinedTwo, JoinedThree?)]>
        where Joined: Schema, JoinedTwo: Schema, JoinedThree: Schema {
        let copy = self.copy()
        return copy.all().flatMapThrowing {
            try $0.map { try ($0.joined(Joined.self), $0.joined(JoinedTwo.self), try? $0.joined(JoinedThree.self)) }
        }
    }

    public func all<Joined, JoinedTwo, JoinedThree, Four>(
        _ joined: Joined.Type,
        _ joinedTwo: JoinedTwo.Type,
        _ joinedThree: JoinedThree.Type,
        _ four: Optional<Four>.Type
    ) -> EventLoopFuture<[(Joined, JoinedTwo, JoinedThree, Four?)]>
        where Joined: Schema, JoinedTwo: Schema, JoinedThree: Schema, Four: Schema {
        let copy = self.copy()
        return copy.all().flatMapThrowing {
            try $0.map { try ($0.joined(Joined.self), $0.joined(JoinedTwo.self), $0.joined(JoinedThree.self), try? $0.joined(Four.self)) }
        }
    }

    public func all<Joined, JoinedTwo>(
        _ joined: Joined.Type,
        _ joinedTwo: Optional<JoinedTwo>.Type
    ) -> EventLoopFuture<[(Joined, JoinedTwo?)]>
        where Joined: Schema, JoinedTwo: Schema {
        let copy = self.copy()
        return copy.all().flatMapThrowing {
            try $0.map { (try $0.joined(Joined.self), try? $0.joined(JoinedTwo.self)) }
        }
    }

    public func first<Joined>(
        _ joined: Joined.Type
    ) -> EventLoopFuture<Joined?>
        where
            Joined: Schema {
        let copy = self.copy()
        return copy.first().flatMapThrowing {
            try $0?.joined(Joined.self)
        }
    }

    public func first<Joined, JoinedTwo>(
        _ joined: Joined.Type, _ joinedTwo: JoinedTwo.Type
    ) -> EventLoopFuture<(Joined, JoinedTwo)?>
        where
        Joined: Schema,
        JoinedTwo: Schema {
        let copy = self.copy()
        return copy.first().flatMapThrowing {
            guard let joined = try $0?.joined(Joined.self), let joinedTwo = try $0?.joined(JoinedTwo.self) else { return nil }
            return (joined, joinedTwo)
        }
    }

    public func first<Joined, JoinedTwo, JoinedThree>(
        _ joined: Joined.Type, _ joinedTwo: JoinedTwo.Type, _ joinedThree: JoinedThree.Type
    ) -> EventLoopFuture<(Joined, JoinedTwo, JoinedThree)?>
        where
        Joined: Schema,
        JoinedTwo: Schema,
        JoinedThree: Schema {
        let copy = self.copy()
        return copy.first().flatMapThrowing {
            guard let joined = try $0?.joined(Joined.self), let joinedTwo = try $0?.joined(JoinedTwo.self), let joinedThree = try $0?.joined(JoinedThree.self) else { return nil }
            return (joined, joinedTwo, joinedThree)
        }
    }

    public func first<Joined, JoinedTwo>(
        _ joined: Joined.Type, _ joinedTwo: Optional<JoinedTwo>.Type
    ) -> EventLoopFuture<(Joined, JoinedTwo?)?>
        where
        Joined: Schema,
        JoinedTwo: Schema {
        let copy = self.copy()
        return copy.first().flatMapThrowing {
            guard let joined = try $0?.joined(Joined.self) else { return nil }
            return (joined, try? $0?.joined(JoinedTwo.self))
        }
    }
}

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

        init(database: Database, repositories: RepositoriesRepresentable, taskRepository: TaskRepository) {
            self.database = database
            self.userRepository = repositories.userRepository
            self.topicRepository = repositories.topicRepository
            self.subtopicRepository = repositories.subtopicRepository
            self.multipleChoiseRepository = repositories.multipleChoiceTaskRepository
            self.taskRepository = taskRepository
        }

        public let database: Database

        private let userRepository: UserRepository
        private let topicRepository: TopicRepository
        private let subtopicRepository: SubtopicRepositoring
        private let multipleChoiseRepository: MultipleChoiseTaskRepository
        private let taskRepository: TaskRepository
    }
}

extension Subject.DatabaseRepository {

    public func tasksWith(subjectID: Subject.ID) -> EventLoopFuture<[GenericTask]> {
        TaskDatabaseModel.query(on: database)
            .join(parent: \TaskDatabaseModel.$subtopic)
            .join(parent: \Subtopic.DatabaseModel.$topic)
            .filter(Topic.DatabaseModel.self, \Topic.DatabaseModel.$subject.$id == subjectID)
            .all()
            .flatMapEachThrowing { try $0.content() }
    }

    public func create(from content: Subject.Create.Data, by user: User?) throws -> EventLoopFuture<Subject> {
        guard let user = user, user.isAdmin else {
            throw Abort(.forbidden)
        }
        let subject = Subject.DatabaseModel(content: content, creator: user)
        return subject.create(on: database)
            .flatMapThrowing {
                try User.ModeratorPrivilege(userID: user.id, subjectID: subject.requireID())
            }
            .create(on: database)
            .flatMapThrowing { try subject.content() }
    }

    public func deleteModelWith(id: Int, by user: User?) throws -> EventLoopFuture<Void> {
        deleteDatabase(Subject.DatabaseModel.self, modelID: id)
    }

    public func updateModelWith(id: Int, to data: Subject.Update.Data, by user: User) throws -> EventLoopFuture<Subject> {
        updateDatabase(Subject.DatabaseModel.self, modelID: id, to: data)
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
        Topic.DatabaseModel.query(on: database)
            .filter(\.$id == topicID)
            .join(parent: \Topic.DatabaseModel.$subject)
            .first(Subject.DatabaseModel.self)
            .unwrap(or: Abort(.badRequest))
            .flatMapThrowing { try $0.content() }
    }

    public func subject(for session: PracticeSessionRepresentable) -> EventLoopFuture<Subject> {
        failable(eventLoop: database.eventLoop) {
            try PracticeSession.DatabaseModel.query(on: database)
                .join(siblings: \PracticeSession.DatabaseModel.$subtopics)
                .join(parent: \Subtopic.DatabaseModel.$topic)
                .join(parent: \Topic.DatabaseModel.$subject)
                .filter(\PracticeSession.DatabaseModel.$id == session.requireID())
                .first(Subject.DatabaseModel.self)
                .unwrap(or: Abort(.internalServerError))
                .flatMapThrowing { try $0.content() }
        }
    }

    public func getSubjectWith(id: Subject.ID) -> EventLoopFuture<Subject> {
        return Subject.DatabaseModel
            .find(id, on: database)
            .unwrap(or: Abort(.badRequest))
            .flatMapThrowing { try $0.content() }
    }

    public func getSubject(in topic: Topic) -> EventLoopFuture<Subject> {
        Subject.DatabaseModel.query(on: database)
            .filter(\Subject.DatabaseModel.$id == topic.subjectID)
            .first()
            .unwrap(or: Abort(.badRequest))
            .flatMapThrowing { try $0.content() }
    }

    public func importContent(_ content: SubjectExportContent) -> EventLoopFuture<Subject> {
        let subject = Subject.DatabaseModel(
            name: content.subject.name,
            category: content.subject.category,
            description: content.subject.description,
            creatorId: 1
        )
        return subject.create(on: database)
            .failableFlatMap {
                try content.topics.map { try self.topicRepository.importContent(from: $0, in: subject.content()) }
                    .flatten(on: self.database.eventLoop)
                    .flatMapThrowing { try subject.content() }
        }
    }

    public func importContent(in subject: Subject, peerWise: [TaskPeerWise], user: User) throws -> EventLoopFuture<Void> {

        let knownTopic = peerWise.filter({ $0.topicName != "" })

        return Topic.DatabaseModel.query(on: database)
            .filter(\Topic.DatabaseModel.$subject.$id == subject.id)
            .count()
            .failableFlatMap { numberOfExistingTopics in

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
                            .failableFlatMap { topic in
                                try self.subtopicRepository
                                    .getSubtopics(in: topic)
                                    .failableFlatMap { subtopics in

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
                                        .flatten(on: self.database.eventLoop)
                                }
                        }
                }
                .flatten(on: self.database.eventLoop)
                .transform(to: ())
        }
    }

    public func allActive(for user: User) throws -> EventLoopFuture<[Subject]> {

        return Subject.DatabaseModel.query(on: database)
            .join(children: \Subject.DatabaseModel.$activeSubjects)
            .filter(User.ActiveSubject.self, \User.ActiveSubject.$user.$id == user.id)
            .all()
            .flatMapEachThrowing { try $0.content() }
    }

    struct SubjectID: Decodable {
        let subjectId: Subject.ID
    }

    public func subjectIDFor(taskIDs: [Int]) -> EventLoopFuture<Subject.ID> {

        return TaskDatabaseModel.query(on: database)
            .join(parent: \TaskDatabaseModel.$subtopic)
            .join(parent: \Subtopic.DatabaseModel.$topic)
            .filter(\TaskDatabaseModel.$id ~~ taskIDs)
            .unique()
            .all(Topic.DatabaseModel.self, \Topic.DatabaseModel.$subject.$id)
            .flatMapThrowing { subjectIDs in
                guard
                    subjectIDs.count == 1,
                    let id = subjectIDs.first
                else {
                    throw Abort(.badRequest)
                }
                return id
        }
    }

    public func subjectIDFor(topicIDs: [Topic.ID]) -> EventLoopFuture<Subject.ID> {

        return Topic.DatabaseModel.query(on: database)
            .filter(\Topic.DatabaseModel.$id ~~ topicIDs)
            .unique()
            .all(\.$subject.$id)
            .flatMapThrowing { subjectIDs in
                guard
                    subjectIDs.count == 1,
                    let id = subjectIDs.first
                else {
                    throw Abort(.badRequest)
                }
                return id
        }
    }

    public func subjectIDFor(subtopicIDs: [Subtopic.ID]) -> EventLoopFuture<Subject.ID> {

        return Subtopic.DatabaseModel.query(on: database)
            .join(parent: \Subtopic.DatabaseModel.$topic)
            .filter(\Subtopic.DatabaseModel.$id ~~ subtopicIDs)
            .unique()
            .all(Topic.DatabaseModel.self, \Topic.DatabaseModel.$subject.$id)
            .flatMapThrowing { subjectIDs in
                guard
                    subjectIDs.count == 1,
                    let id = subjectIDs.first
                else {
                    throw Abort(.badRequest)
                }
                return id
        }
    }

    public func mark(inactive subject: Subject, for user: User) throws -> EventLoopFuture<Void> {

        User.ActiveSubject.query(on: database)
            .filter(\User.ActiveSubject.$subject.$id == subject.id)
            .filter(\User.ActiveSubject.$user.$id == user.id)
            .first()
            .unwrap(or: Abort(.badRequest))
            .delete(on: database)
    }

    public func mark(active subject: Subject, canPractice: Bool, for user: User) throws -> EventLoopFuture<Void> {
        User.ActiveSubject(
            userID: user.id,
            subjectID: subject.id,
            canPractice: canPractice
        )
            .create(on: database)
    }

    public func grantModeratorPrivilege(for userID: User.ID, in subjectID: Subject.ID, by moderator: User) throws -> EventLoopFuture<Void> {

        userRepository
            .isModerator(user: moderator, subjectID: subjectID)
            .ifFalse(throw: Abort(.forbidden))
            .flatMap {
                User.ModeratorPrivilege(
                    userID: userID,
                    subjectID: subjectID
                )
                    .create(on: self.database)
        }
    }

    public func revokeModeratorPrivilege(for userID: User.ID, in subjectID: Subject.ID, by moderator: User) throws -> EventLoopFuture<Void> {
        guard moderator.id != userID else {
            throw Abort(.badRequest)
        }
        return try userRepository
            .isModerator(user: moderator, subjectID: subjectID)
            .ifFalse(throw: Abort(.forbidden))
            .flatMap {

                User.ModeratorPrivilege.query(on: self.database)
                    .filter(\.$user.$id == userID)
                    .filter(\.$subject.$id == subjectID)
                    .first()
                    .unwrap(or: Abort(.badRequest))
                    .flatMap { privilege in
                        privilege.delete(on: self.database)
                }
        }
    }

    public func active(subject: Subject, for user: User) throws -> EventLoopFuture<User.ActiveSubject?> {

        User.ActiveSubject.query(on: database)
            .filter(\.$user.$id == user.id)
            .filter(\.$subject.$id == subject.id)
            .first()
    }

    struct ActiveSubjectQuery: Codable {
        let canPractice: Bool
    }

    public func allSubjects(for user: User) throws -> EventLoopFuture<[Subject.ListOverview]> {

        return Subject.DatabaseModel.query(on: database)
            .all()
            .flatMap { subjects in

                User.ActiveSubject.query(on: self.database)
                    .filter(\.$user.$id == user.id)
                    .all()
                    .map { activeSubjects in
                        subjects.map { subject in
                            Subject.ListOverview(
                                subject: subject,
                                active: activeSubjects
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

        return Subject.DatabaseModel.find(subjectID, on: database)
            .unwrap(or: Abort(.badRequest))
            .flatMap { subject in

                var query = TaskDatabaseModel.query(on: self.database)
                    .withDeleted()
                    .join(FlashCardTask.self, on: \FlashCardTask.$id == \TaskDatabaseModel.$id, method: .inner)
                    .join(parent: \TaskDatabaseModel.$subtopic)
                    .join(parent: \Subtopic.DatabaseModel.$topic)
                    .filter(\TaskDatabaseModel.$description == nil)
                    .filter(Topic.DatabaseModel.self, \Topic.DatabaseModel.$subject.$id == subjectID)

                if let subtopicIDs = filter.subtopicIDs {
                    query = query.filter(Subtopic.DatabaseModel.self, \Subtopic.DatabaseModel.$id ~~ subtopicIDs)
                }

                return query.all(with: \TaskDatabaseModel.$subtopic, \Subtopic.DatabaseModel.$topic)
                    .flatMap { data in

                        TaskSolution.DatabaseModel.query(on: self.database)
                            .filter(\.$task.$id ~~ data.compactMap { $0.id })
                            .all()
                            .map { solutions in

                                Subject.Compendium(
                                    subjectID: subjectID,
                                    subjectName: subject.name,
                                    topics: data.group(by: \TaskDatabaseModel.subtopic.topic.id)
                                        .map { _, topicData in

                                            Subject.Compendium.TopicData(
                                                name: topicData.first!.subtopic.topic.name,
                                                chapter: topicData.first!.subtopic.topic.chapter,
                                                subtopics: topicData.group(by: \.$subtopic.id)
                                                    .map { subtopicID, questions in

                                                        Subject.Compendium.SubtopicData(
                                                            subjectID: subjectID,
                                                            subtopicID: subtopicID,
                                                            name: questions.first!.subtopic.name,
                                                            questions: questions.map { question in

                                                                Subject.Compendium.QuestionData(
                                                                    question: question.question,
                                                                    solution: solutions.first(where: { $0.$task.id == question.id })?.solution ?? ""
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

    public func overviewFor(id: Subject.ID) -> EventLoopFuture<Subject.Overview> {
        Subject.DatabaseModel.query(on: database)
            .filter(\.$id == id)
            .with(\.$topics)
            .first()
            .unwrap(or: Abort(.badRequest))
            .flatMapThrowing { subject in
                try Subject.Overview(
                    id: subject.requireID(),
                    name: subject.name,
                    description: subject.description,
                    category: subject.description,
                    topics: subject.topics.map { try $0.content() }
                )
        }
    }

    public func overviewContaining(subtopicID: Subtopic.ID) -> EventLoopFuture<Subject.Overview> {
        Subject.DatabaseModel.query(on: database)
            .join(children: \Subject.DatabaseModel.$topics)
            .join(children: \Topic.DatabaseModel.$subtopics)
            .filter(Subtopic.DatabaseModel.self, \Subtopic.DatabaseModel.$id == subtopicID)
            .with(\.$topics)
            .first()
            .unwrap(or: Abort(.badRequest))
            .flatMapThrowing { subject in
                try Subject.Overview(
                    id: subject.requireID(),
                    name: subject.name,
                    description: subject.description,
                    category: subject.description,
                    topics: subject.topics.map { try $0.content() }
                )
        }
    }

    public func creatorTasksWith(subjectID: Subject.ID) -> EventLoopFuture<[CreatorTaskContent]> {

        return TaskDatabaseModel.query(on: database)
            .join(parent: \TaskDatabaseModel.$creator)
            .join(parent: \TaskDatabaseModel.$subtopic)
            .join(parent: \Subtopic.DatabaseModel.$topic)
            .join(superclass: MultipleChoiceTask.DatabaseModel.self, with: TaskDatabaseModel.self, method: .left)
            .filter(Topic.DatabaseModel.self, \Topic.DatabaseModel.$subject.$id == subjectID)
            .all(TaskDatabaseModel.self, Topic.DatabaseModel.self, User.DatabaseModel.self, MultipleChoiceTask.DatabaseModel?.self)
            .flatMapEachThrowing { (task, topic, creator, multipleChoiceTask) in
                try CreatorTaskContent(
                    task: task.content(),
                    topic: topic.content(),
                    creator: creator.content(),
                    isMultipleChoise: multipleChoiceTask != nil
                )
        }
    }

    public func tasksWith(subjectID: Subject.ID, user: User, query: TaskOverviewQuery?, maxAmount: Int?, withSoftDeleted: Bool) -> EventLoopFuture<[CreatorTaskContent]> {
        taskRepository.getTasks(in: subjectID, user: user, query: query, maxAmount: maxAmount, withSoftDeleted: withSoftDeleted)
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

extension TaskSolution.Unverified {

    init(task: TaskDatabaseModel, solution: TaskSolution, choises: [MultipleChoiseTaskChoise]) throws {
        self.init(
            taskID: try task.requireID(),
            solutionID: solution.id,
            description: task.description,
            question: task.question,
            solution: solution.solution,
            choises: try choises.map { try .init(choice: $0) }
        )
    }
}

extension MultipleChoiceTaskChoice {
    init(choice: MultipleChoiseTaskChoise) throws {
        try self.init(
            id: choice.requireID(),
            choice: choice.choice,
            isCorrect: choice.isCorrect
        )
    }
}

extension Subject.ListOverview {
    init(subject: Subject.DatabaseModel, active: [User.ActiveSubject]) {
        self.init(
            id: subject.id ?? 0,
            name: subject.name,
            description: subject.description,
            category: subject.category,
            isActive: active.contains(where: { $0.$subject.id == subject.id })
        )
    }
}
