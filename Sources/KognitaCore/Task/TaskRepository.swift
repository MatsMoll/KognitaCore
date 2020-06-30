//
//  TaskRepository.swift
//  Async
//
//  Created by Mats Mollestad on 12/04/2019.
//

import Vapor
import FluentKit
import FluentSQL

protocol TaskRepository {
    func all() throws -> EventLoopFuture<[TaskDatabaseModel]>
    func create(from content: TaskDatabaseModel.Create.Data, by user: User?) throws -> EventLoopFuture<TaskDatabaseModel>
    func getTaskTypePath(for id: Task.ID) throws -> EventLoopFuture<String>
    func getTasks(in subject: Subject) throws -> EventLoopFuture<[TaskContent]>
    func taskFor(id: TaskDatabaseModel.IDValue) -> EventLoopFuture<TaskDatabaseModel>
}

extension TaskDatabaseModel {

    enum Create {
        struct Data {
            let content: TaskCreationContentable
            let subtopicID: Subtopic.ID
            let solution: String
        }
        typealias Response = TaskDatabaseModel

        enum Errors: Error {
            case invalidTopic
        }
    }

    struct DatabaseRepository: TaskRepository, DatabaseConnectableRepository {

        public let database: Database

        internal var userRepository: UserRepository
        private var taskSolutionRepository: TaskSolutionRepositoring { TaskSolution.DatabaseRepository(database: database, userRepository: userRepository) }
        private var taskRepository: TaskRepository { TaskDatabaseModel.DatabaseRepository(database: database, userRepository: userRepository) }
    }
}

extension TaskDatabaseModel.DatabaseRepository {

    func all() throws -> EventLoopFuture<[TaskDatabaseModel]> {
        TaskDatabaseModel.query(on: database).all()
    }

    public func create(from content: TaskDatabaseModel.Create.Data, by user: User?) throws -> EventLoopFuture<TaskDatabaseModel> {

        guard content.solution.removeCharacters(from: .whitespaces).isEmpty == false else {
            return database.eventLoop.future(error: Abort(.badRequest))
        }

        guard let user = user else { throw Abort(.unauthorized) }

        let task = try TaskDatabaseModel(
            content: content.content,
            subtopicID: content.subtopicID,
            creator: user
        )
        return task.save(on: database)
            .failableFlatMap {
                try self.taskSolutionRepository.create(
                    from: TaskSolution.Create.Data(
                        solution: content.solution,
                        presentUser: true,
                        taskID: task.requireID()
                ),
                    by: user
                )
        }
        .transform(to: task)
    }

    public func getTasks(in subject: Subject) throws -> EventLoopFuture<[TaskContent]> {

        TaskDatabaseModel.query(on: database)
            .join(parent: \TaskDatabaseModel.$subtopic)
            .join(parent: \TaskDatabaseModel.$creator)
            .join(parent: \Subtopic.DatabaseModel.$topic)
            .filter(Topic.DatabaseModel.self, \Topic.DatabaseModel.$subject.$id == subject.id)
            .all(with: \.$creator, \.$subtopic, \Subtopic.DatabaseModel.$topic)
            .flatMapEach(on: database.eventLoop) { (task: TaskDatabaseModel) in
                failable(eventLoop: self.database.eventLoop) {
                    try self.taskRepository
                        .getTaskTypePath(for: task.requireID())
                        .flatMapThrowing { path in
                            try TaskContent(
//                                task: task,
                                topic: task.subtopic.topic.content(),
                                subject: subject,
                                creator: task.creator.content(),
                                taskTypePath: path
                            )
                    }
                }
        }
//            .flatMap { tasks in
//                try tasks.map { content in
//                    try self.taskRepository.getTaskTypePath(for: content.0.1.requireID()).map { path in
//                        try TaskContent(
//                            task: content.0.1,
//                            topic: content.0.0.content(),
//                            subject: subject,
//                            creator: content.1.content(),
//                            taskTypePath: path
//                        )
//                    }
//                }.flatten(on: self.conn)
//        }
    }

    func taskFor(id: TaskDatabaseModel.IDValue) -> EventLoopFuture<TaskDatabaseModel> {
        TaskDatabaseModel.find(id, on: database).unwrap(or: Abort(.badRequest))
    }

    public func getTasks(in topic: Topic) throws -> EventLoopFuture<[TaskDatabaseModel]> {
        return TaskDatabaseModel.query(on: database)
            .join(parent: \TaskDatabaseModel.$subtopic)
            .filter(Subtopic.DatabaseModel.self, \Subtopic.DatabaseModel.$topic.$id == topic.id)
            .all()
    }

//    public func getTasks<A>(where filter: FilterOperator<PostgreSQLDatabase, A>, maxAmount: Int? = nil, withSoftDeleted: Bool = false) throws -> EventLoopFuture<[TaskContent]> {
//
//        return TaskDatabaseModel.query(on: conn, withSoftDeleted: withSoftDeleted)
//            .join(\Subtopic.DatabaseModel.id, to: \TaskDatabaseModel.subtopicID)
//            .join(\Topic.DatabaseModel.id, to: \Subtopic.DatabaseModel.topicID)
//            .join(\Subject.DatabaseModel.id, to: \Topic.DatabaseModel.subjectId)
//            .join(\User.DatabaseModel.id, to: \TaskDatabaseModel.creatorID)
//            .filter(filter)
//            .alsoDecode(Topic.DatabaseModel.self)
//            .alsoDecode(Subject.DatabaseModel.self)
//            .alsoDecode(User.DatabaseModel.self)
//            .range(lower: 0, upper: maxAmount)
//            .all()
//            .flatMap { tasks in
//                try tasks.map { content in
//                    try self.taskRepository
//                        .getTaskTypePath(for: content.0.0.0.requireID())
//                        .map { path in
//                            try TaskContent(
//                                task: content.0.0.0,
//                                topic: content.0.0.1.content(),
//                                subject: content.0.1.content(),
//                                creator: content.1.content(),
//                                taskTypePath: path
//                            )
//                    }
//                }.flatten(on: self.conn)
//        }
//    }

    public struct CreatorOverviewQuery: Codable {
        let taskQuestion: String?
        let topics: [Topic.ID]
    }

    public func getTasks(in subjectId: Subject.ID, user: User, query: CreatorOverviewQuery? = nil, maxAmount: Int? = nil, withSoftDeleted: Bool = false) throws -> EventLoopFuture<[CreatorTaskContent]> {

        userRepository
            .isModerator(user: user, subjectID: subjectId)
            .flatMap { isModerator in

                var databaseQuery = TaskDatabaseModel.query(on: self.database)
                    .join(parent: \TaskDatabaseModel.$creator)
                    .join(parent: \TaskDatabaseModel.$subtopic)
                    .join(parent: \Subtopic.DatabaseModel.$topic)
                    .join(MultipleChoiceTask.DatabaseModel.self, on: \MultipleChoiceTask.DatabaseModel.$id == \TaskDatabaseModel.$id, method: .left)
                    .filter(Topic.DatabaseModel.self, \Topic.DatabaseModel.$subject.$id == subjectId)
                    .range(lower: 0, upper: maxAmount)

                if isModerator {
                    databaseQuery = databaseQuery.withDeleted()
                }

                if let topics = query?.topics, topics.isEmpty == false {
                    databaseQuery = databaseQuery.filter(Topic.DatabaseModel.self, \Topic.DatabaseModel.$id ~~ topics)
                }
                if let question = query?.taskQuestion, question.isEmpty == false {
                    databaseQuery = databaseQuery.filter(\TaskDatabaseModel.$question, .custom("ILIKE"), "%\(question)%")
                }
                if isModerator == false {
                    databaseQuery = databaseQuery.filter(\TaskDatabaseModel.$isTestable == false)
                }

                return databaseQuery
                    .all(TaskDatabaseModel.self, User.DatabaseModel.self, Topic.DatabaseModel.self, MultipleChoiceTask.DatabaseModel?.self)
                    .flatMapThrowing { content in
                        try content.map { taskContent in
                            try CreatorTaskContent(
//                                task: taskContent.0,
                                topic: taskContent.2.content(),
                                creator: taskContent.1.content(),
                                isMultipleChoise: taskContent.3 != nil
                            )
                        }
                }
        }
    }

    struct NumberInputTaskKey: Content {
        let correctAnswer: Double?  // NumberInputTask
    }

    struct MultipleChoiseTaskKey: Content {
        let isMultipleSelect: Bool?  // MultipleChoiseTask
    }

    public func getTaskTypePath(for id: Task.ID) throws -> EventLoopFuture<String> {

        // FIXME: Optimize better
        return TaskDatabaseModel.query(on: database)
            .withDeleted()
            .filter(\.$id == id)
            .join(MultipleChoiceTask.DatabaseModel.self, on: \MultipleChoiceTask.DatabaseModel.$id == \TaskDatabaseModel.$id, method: .left)
            .first(TaskDatabaseModel.self, MultipleChoiceTask.DatabaseModel?.self)
            .unwrap(or: Abort(.internalServerError))
            .map { (_, multiple) in
                if multiple != nil {
                    return "tasks/multiple-choise"
                } else {
                    return "tasks/flash-card"
                }
        }
    }

    public func getNumberOfTasks(in subtopicIDs: Subtopic.ID...) -> EventLoopFuture<Int> {
        return TaskDatabaseModel.query(on: database)
            .filter(\.$subtopic.$id ~~ subtopicIDs)
            .count()
    }

    public func getTaskCreators(on database: Database) -> EventLoopFuture<[TaskCreators]> {

        return database.eventLoop.future(error: Abort(.notImplemented))
//        return conn.select()
//            .column(.count(.all, as: "taskCount"))
//            .column(.keyPath(\User.DatabaseModel.id, as: "userID"))
//            .column(.keyPath(\User.DatabaseModel.username, as: "username"))
//            .from(TaskDatabaseModel.self)
//            .join(\TaskDatabaseModel.creatorID, to: \User.DatabaseModel.id)
//            .groupBy(\User.DatabaseModel.id)
//            .all(decoding: TaskCreators.self)
    }

    public func taskType(with id: Task.ID, on database: Database) -> EventLoopFuture<TaskType?> {

        return database.eventLoop.future(error: Abort(.notImplemented))

//        return conn.select()
//            .all(table: TaskDatabaseModel.self)
//            .all(table: MultipleChoiceTask.DatabaseModel.self)
//            .from(TaskDatabaseModel.self)
//            .where(\TaskDatabaseModel.id == id)
//            .join(\TaskDatabaseModel.id, to: \MultipleChoiceTask.DatabaseModel.id, method: .left)
//            .first(decoding: TaskDatabaseModel.self, MultipleChoiceTask.DatabaseModel?.self)
//            .map { task in
//                guard let task = task else { return nil }
//                return TaskType(content: task)
//        }
    }

    public func taskWith(
        id: Int,
        on database: Database
    ) throws -> EventLoopFuture<TaskType> {

        throw Abort(.notImplemented)
//        return conn.select()
//            .all(table: TaskDatabaseModel.self)
//            .all(table: MultipleChoiceTask.DatabaseModel.self)
//            .from(TaskDatabaseModel.self)
//            .join(\TaskDatabaseModel.id, to: \MultipleChoiceTask.DatabaseModel.id, method: .left)
//            .first(decoding: TaskDatabaseModel.self, MultipleChoiceTask.DatabaseModel?.self)
//            .unwrap(or: Abort(.badRequest))
//            .map { taskContent in
//                TaskType(content: taskContent)
//        }
    }

    public func examTasks(subjectID: Subject.ID) -> EventLoopFuture<[TaskDatabaseModel]> {
        return database.eventLoop.future(error: Abort(.notImplemented))
//        TaskDatabaseModel.query(on: conn)
//            .join(\Subtopic.DatabaseModel.id, to: \TaskDatabaseModel.subtopicID)
//            .join(\Topic.DatabaseModel.id, to: \Subtopic.DatabaseModel.topicID)
//            .filter(\.isTestable == true)
//            .filter(\Topic.DatabaseModel.subjectId == subjectID)
//            .all()
    }
}

public struct TaskCreators: Content {

    public let userID: User.ID

    public let username: String

    public let taskCount: Int
}
