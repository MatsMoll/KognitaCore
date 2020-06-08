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

    enum Create {
        struct Data {
            let content: TaskCreationContentable
            let subtopicID: Subtopic.ID
            let solution: String
        }
        typealias Response = Task

        enum Errors: Error {
            case invalidTopic
        }
    }

    struct DatabaseRepository: TaskRepository, DatabaseConnectableRepository {

        typealias DatabaseModel = Task

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

        return Topic.DatabaseModel.query(on: conn)
            .join(\Subtopic.DatabaseModel.topicId, to: \Topic.DatabaseModel.id)
            .join(\Task.subtopicID, to: \Subtopic.DatabaseModel.id)
            .join(\User.DatabaseModel.id, to: \Task.creatorID)
            .filter(\.subjectId == subject.id)
            .alsoDecode(Task.self)
            .alsoDecode(User.DatabaseModel.self)
            .all()
            .flatMap { tasks in
                try tasks.map { content in
                    try self.taskRepository.getTaskTypePath(for: content.0.1.requireID()).map { path in
                        try TaskContent(
                            task: content.0.1,
                            topic: content.0.0.content(),
                            subject: subject,
                            creator: content.1.content(),
                            taskTypePath: path
                        )
                    }
                }.flatten(on: self.conn)
        }
    }

    public func getTasks(in topic: Topic) throws -> EventLoopFuture<[Task]> {
        return Task.query(on: conn)
            .join(\Subtopic.DatabaseModel.id, to: \Task.subtopicID)
            .filter(\Subtopic.DatabaseModel.topicId == topic.id)
            .all()
    }

    public func getTasks<A>(where filter: FilterOperator<PostgreSQLDatabase, A>, maxAmount: Int? = nil, withSoftDeleted: Bool = false) throws -> EventLoopFuture<[TaskContent]> {

        return Task.query(on: conn, withSoftDeleted: withSoftDeleted)
            .join(\Subtopic.DatabaseModel.id, to: \Task.subtopicID)
            .join(\Topic.DatabaseModel.id, to: \Subtopic.DatabaseModel.topicId)
            .join(\Subject.DatabaseModel.id, to: \Topic.DatabaseModel.subjectId)
            .join(\User.DatabaseModel.id, to: \Task.creatorID)
            .filter(filter)
            .alsoDecode(Topic.DatabaseModel.self)
            .alsoDecode(Subject.DatabaseModel.self)
            .alsoDecode(User.DatabaseModel.self)
            .range(lower: 0, upper: maxAmount)
            .all()
            .flatMap { tasks in
                try tasks.map { content in
                    try self.taskRepository
                        .getTaskTypePath(for: content.0.0.0.requireID())
                        .map { path in
                            try TaskContent(
                                task: content.0.0.0,
                                topic: content.0.0.1.content(),
                                subject: content.0.1.content(),
                                creator: content.1.content(),
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
                    .join(\Subtopic.DatabaseModel.id, to: \Task.subtopicID)
                    .join(\Topic.DatabaseModel.id, to: \Subtopic.DatabaseModel.topicId)
                    .join(\MultipleChoiceTask.DatabaseModel.id, to: \Task.id, method: .left)
                    .filter(\Topic.DatabaseModel.subjectId == subjectId)
                    .alsoDecode(User.DatabaseModel.self)
                    .alsoDecode(Topic.DatabaseModel.self)
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
                        try content.map { taskContent in
                            try CreatorTaskContent(
                                task: taskContent.0.0.0,
                                topic: taskContent.0.1.content(),
                                creator: taskContent.0.0.1.content(),
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
            .join(\MultipleChoiceTask.DatabaseModel.id, to: \Task.id, method: .left)
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
            .column(.keyPath(\User.DatabaseModel.id, as: "userID"))
            .column(.keyPath(\User.DatabaseModel.username, as: "username"))
            .from(Task.self)
            .join(\Task.creatorID, to: \User.DatabaseModel.id)
            .groupBy(\User.DatabaseModel.id)
            .all(decoding: TaskCreators.self)
    }

    public func taskType(with id: Task.ID, on conn: PostgreSQLConnection) -> EventLoopFuture<TaskType?> {

        return conn.select()
            .all(table: Task.self)
            .all(table: MultipleChoiceTask.DatabaseModel.self)
            .from(Task.self)
            .where(\Task.id == id)
            .join(\Task.id, to: \MultipleChoiceTask.DatabaseModel.id, method: .left)
            .first(decoding: Task.self, MultipleChoiceTask.DatabaseModel?.self)
            .map { task in
                guard let task = task else { return nil }
                return TaskType(content: task)
        }
    }

    public func taskWith(
        id: Int,
        on conn: PostgreSQLConnection
    ) throws -> EventLoopFuture<TaskType> {

        return conn.select()
            .all(table: Task.self)
            .all(table: MultipleChoiceTask.DatabaseModel.self)
            .from(Task.self)
            .join(\Task.id, to: \MultipleChoiceTask.DatabaseModel.id, method: .left)
            .first(decoding: Task.self, MultipleChoiceTask.DatabaseModel?.self)
            .unwrap(or: Abort(.badRequest))
            .map { taskContent in
                TaskType(content: taskContent)
        }
    }

    public func examTasks(subjectID: Subject.ID) -> EventLoopFuture<[Task]> {
        Task.query(on: conn)
            .join(\Subtopic.DatabaseModel.id, to: \Task.subtopicID)
            .join(\Topic.DatabaseModel.id, to: \Subtopic.DatabaseModel.topicId)
            .filter(\.isTestable == true)
            .filter(\Topic.DatabaseModel.subjectId == subjectID)
            .all()
    }
}

public struct TaskCreators: Content {

    public let userID: User.ID

    public let username: String

    public let taskCount: Int
}
