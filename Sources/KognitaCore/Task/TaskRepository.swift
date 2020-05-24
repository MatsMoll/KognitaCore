//
//  TaskRepository.swift
//  Async
//
//  Created by Mats Mollestad on 12/04/2019.
//

import FluentPostgreSQL
import FluentSQL
import Vapor

protocol TaskRepository: CreateModelRepository,
    RetriveAllModelsRepository
    where
    Model == Task,
    CreateData == Task.Create.Data,
    CreateResponse == Task,
    ResponseModel == Task {
    func getTaskTypePath(for id: Task.ID) throws -> EventLoopFuture<String>
    func getTasks(in subject: Subject) throws -> EventLoopFuture<[TaskContent]>
}

extension Task {

    public enum Create {
        public struct Data {
            let content: TaskCreationContentable
            let subtopicID: Subtopic.ID
            let solution: String
        }
        public typealias Response = Task

        public enum Errors: Error {
            case invalidTopic
        }
    }

    public struct DatabaseRepository: TaskRepository, DatabaseConnectableRepository {

        public let conn: DatabaseConnectable
        private var userRepository: some UserRepository { User.DatabaseRepository(conn: conn) }
        private var taskSolutionRepository: some TaskSolutionRepositoring { TaskSolution.DatabaseRepository(conn: conn) }
        private var taskRepository: some TaskRepository { Task.DatabaseRepository(conn: conn) }
    }
}

extension Task.DatabaseRepository {

    public func create(from content: Task.Create.Data, by user: User?) throws -> EventLoopFuture<Task> {

        guard let user = user else { throw Abort(.unauthorized) }

        return try Task(
            content: content.content,
            subtopicID: content.subtopicID,
            creator: user
        )
            .save(on: conn)
            .flatMap { task in
                try self.taskSolutionRepository.create(
                    from: TaskSolution.Create.Data(
                        solution: content.solution,
                        presentUser: true,
                        taskID: task.requireID()
                ),
                    by: user
                )
                    .transform(to: task)
        }
    }

    public func getTasks(in subject: Subject) throws -> EventLoopFuture<[TaskContent]> {

        return try subject.topics
            .query(on: conn)
            .join(\Subtopic.topicId, to: \Topic.id)
            .join(\Task.subtopicID, to: \Subtopic.id)
            .join(\User.id, to: \Task.creatorID)
            .alsoDecode(Task.self)
            .alsoDecode(User.self)
            .all()
            .flatMap { tasks in
                try tasks.map { content in
                    try self.taskRepository.getTaskTypePath(for: content.0.1.requireID()).map { path in
                        TaskContent(
                            task: content.0.1,
                            topic: content.0.0,
                            subject: subject,
                            creator: content.1,
                            taskTypePath: path
                        )
                    }
                }.flatten(on: self.conn)
        }
    }

    public func getTasks(in topic: Topic) throws -> EventLoopFuture<[Task]> {
        return try Task.query(on: conn)
            .join(\Subtopic.id, to: \Task.subtopicID)
            .filter(\Subtopic.topicId == topic.requireID())
            .all()
    }

    public func getTasks<A>(where filter: FilterOperator<PostgreSQLDatabase, A>, maxAmount: Int? = nil, withSoftDeleted: Bool = false) throws -> EventLoopFuture<[TaskContent]> {

        return Task.query(on: conn, withSoftDeleted: withSoftDeleted)
            .join(\Subtopic.id, to: \Task.subtopicID)
            .join(\Topic.id, to: \Subtopic.topicId)
            .join(\Subject.id, to: \Topic.subjectId)
            .join(\User.id, to: \Task.creatorID)
            .filter(filter)
            .alsoDecode(Topic.self)
            .alsoDecode(Subject.self)
            .alsoDecode(User.self)
            .range(lower: 0, upper: maxAmount)
            .all()
            .flatMap { tasks in
                try tasks.map { content in
                    try self.taskRepository
                        .getTaskTypePath(for: content.0.0.0.requireID())
                        .map { path in
                            TaskContent(
                                task: content.0.0.0,
                                topic: content.0.0.1,
                                subject: content.0.1,
                                creator: content.1,
                                taskTypePath: path
                            )
                    }
                }.flatten(on: self.conn)
        }
    }

    public struct CreatorOverviewQuery: Codable {
        let taskQuestion: String?
        let topics: [Topic.ID]
    }

    public func getTasks(in subjectId: Subject.ID, user: User, query: CreatorOverviewQuery? = nil, maxAmount: Int? = nil, withSoftDeleted: Bool = false) throws -> EventLoopFuture<[CreatorTaskContent]> {

        try userRepository
            .isModerator(user: user, subjectID: subjectId)
            .map { true }
            .catchMap { _ in false }
            .flatMap { isModerator in

                let useSoftDeleted = isModerator ? withSoftDeleted : false
                var dbQuery = Task.query(on: self.conn, withSoftDeleted: useSoftDeleted)
                    .join(\User.id, to: \Task.creatorID)
                    .join(\Subtopic.id, to: \Task.subtopicID)
                    .join(\Topic.id, to: \Subtopic.topicId)
                    .join(\MultipleChoiseTask.id, to: \Task.id, method: .left)
                    .filter(\Topic.subjectId == subjectId)
                    .alsoDecode(User.self)
                    .alsoDecode(Topic.self)
                    .alsoDecode(MultipleChoiseTaskKey.self, "MultipleChoiseTask")
                    .range(lower: 0, upper: maxAmount)

                if let topics = query?.topics, topics.isEmpty == false {
                    dbQuery = dbQuery.filter(\Topic.id ~~ topics)
                }
                if let question = query?.taskQuestion, question.isEmpty == false {
                    dbQuery = dbQuery.filter(\Task.question, .ilike, "%\(question)%")
                }
                if isModerator == false {
                    dbQuery = dbQuery.filter(\Task.isTestable == false)
                }

                return dbQuery
                    .all()
                    .map { content in
                        content.map { taskContent in
                            CreatorTaskContent(
                                task: taskContent.0.0.0,
                                topic: taskContent.0.1,
                                creator: taskContent.0.0.1,
                                isMultipleChoise: taskContent.1.isMultipleSelect != nil
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

        return Task.query(on: conn, withSoftDeleted: true)
            .filter(\.id == id)
            .join(\MultipleChoiseTask.id, to: \Task.id, method: .left)
            .decode(data: MultipleChoiseTaskKey.self, "MultipleChoiseTask")
            .first()
            .unwrap(or: Abort(.internalServerError))
            .map { multiple in

                if multiple.isMultipleSelect != nil {
                    return "tasks/multiple-choise"
                } else {
                    return "tasks/flash-card"
                }
        }
    }

    public func getNumberOfTasks(in subtopicIDs: Subtopic.ID...) -> EventLoopFuture<Int> {
        return Task.query(on: conn)
            .filter(\.subtopicID ~~ subtopicIDs)
            .count()
    }

    public func getTaskCreators(on conn: PostgreSQLConnection) -> EventLoopFuture<[TaskCreators]> {

        return conn.select()
            .column(.count(.all, as: "taskCount"))
            .column(.keyPath(\User.id, as: "userID"))
            .column(.keyPath(\User.username, as: "username"))
            .from(Task.self)
            .join(\Task.creatorID, to: \User.id)
            .groupBy(\User.id)
            .all(decoding: TaskCreators.self)
    }

    public func taskType(with id: Task.ID, on conn: PostgreSQLConnection) -> EventLoopFuture<(Task, MultipleChoiseTask?)?> {

        return conn.select()
            .all(table: Task.self)
            .all(table: MultipleChoiseTask.self)
            .from(Task.self)
            .where(\Task.id == id)
            .join(\Task.id, to: \MultipleChoiseTask.id, method: .left)
            .first(decoding: Task.self, MultipleChoiseTask?.self)
    }

    public func taskWith(
        id: Int,
        on conn: PostgreSQLConnection
    ) throws -> EventLoopFuture<TaskType> {

        return conn.select()
            .all(table: Task.self)
            .all(table: MultipleChoiseTask.self)
            .from(Task.self)
            .join(\Task.id, to: \MultipleChoiseTask.id, method: .left)
            .first(decoding: Task.self, MultipleChoiseTask?.self)
            .unwrap(or: Abort(.badRequest))
            .map { taskContent in
                TaskType(content: taskContent)
        }
    }

    public func examTasks(subjectID: Subject.ID) -> EventLoopFuture<[Task]> {
        Task.query(on: conn)
            .join(\Subtopic.id, to: \Task.subtopicID)
            .join(\Topic.id, to: \Subtopic.topicId)
            .filter(\.isTestable == true)
            .filter(\Topic.subjectId == subjectID)
            .all()
    }
}

public struct TaskCreators: Content {

    public let userID: User.ID

    public let username: String

    public let taskCount: Int
}
