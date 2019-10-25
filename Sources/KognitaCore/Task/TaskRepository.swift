//
//  TaskRepository.swift
//  Async
//
//  Created by Mats Mollestad on 12/04/2019.
//

import FluentPostgreSQL
import FluentSQL
import Vapor

extension Task {
    
    public struct Create: KognitaRequestData {
        public struct Data {
            let content: TaskCreationContentable
            let subtopic: Subtopic
        }
        public typealias Response = Task

        public enum Errors : Error {
            case invalidTopic
        }
    }
    
    public final class Repository {
        public typealias Model = Task
        
        public static let shared = Repository()
    }
}

extension Task.Repository : KognitaRepository {
    
    public static func create(from content: Task.Create.Data, by user: User?, on conn: DatabaseConnectable) throws -> EventLoopFuture<Task> {
        guard let user = user else { throw Abort(.forbidden) }
        
        return try Task(content: content.content, subtopic: content.subtopic, creator: user)
            .save(on: conn)
    }

    public static func getTasks(in subject: Subject, with conn: DatabaseConnectable) throws -> Future<[TaskContent]> {

        return try subject.topics
            .query(on: conn)
            .join(\Subtopic.topicId, to: \Topic.id)
            .join(\Task.subtopicId, to: \Subtopic.id)
            .join(\User.id, to: \Task.creatorId)
            .alsoDecode(Task.self)
            .alsoDecode(User.self)
            .all()
            .flatMap { tasks in
                try tasks.map { content in
                    try content.0.1.getTaskTypePath(conn).map { path in
                        TaskContent(
                            task: content.0.1,
                            topic: content.0.0,
                            subject: subject,
                            creator: content.1,
                            taskTypePath: path
                        )
                    }
                }.flatten(on: conn)
        }
    }

    public static func getTasks(in topic: Topic, with conn: DatabaseConnectable) throws -> Future<[Task]> {
        return try Task.query(on: conn)
            .join(\Subtopic.id, to: \Task.subtopicId)
            .filter(\Subtopic.topicId == topic.requireID())
            .all()
    }

    public static func getTasks<A>(where filter: FilterOperator<PostgreSQLDatabase, A>, maxAmount: Int? = nil, withSoftDeleted: Bool = false, conn: DatabaseConnectable) throws -> Future<[TaskContent]> {

        return Task.query(on: conn, withSoftDeleted: withSoftDeleted)
            .join(\Subtopic.id, to: \Task.subtopicId)
            .join(\Topic.id, to: \Subtopic.topicId)
            .join(\Subject.id, to: \Topic.subjectId)
            .join(\User.id, to: \Task.creatorId)
            .filter(filter)
            .alsoDecode(Topic.self)
            .alsoDecode(Subject.self)
            .alsoDecode(User.self)
            .range(lower: 0, upper: maxAmount)
            .all()
            .flatMap { tasks in
                try tasks.map { content in
                    try content.0.0.0.getTaskTypePath(conn).map { path in
                        TaskContent(
                            task: content.0.0.0,
                            topic: content.0.0.1,
                            subject: content.0.1,
                            creator: content.1,
                            taskTypePath: path
                        )
                    }
                }.flatten(on: conn)
        }
    }

    
    struct NumberInputTaskKey: Content {
        let correctAnswer: Double?  // NumberInputTask
    }

    struct MultipleChoiseTaskKey: Content {
        let isMultipleSelect: Bool?  // MultipleChoiseTask
    }
    
    public static func getTaskTypePath(for id: Task.ID, conn: DatabaseConnectable) throws -> Future<String> {

        return Task.query(on: conn, withSoftDeleted: true)
            .filter(\.id == id)
            .join(\MultipleChoiseTask.id, to: \Task.id, method: .left)
            .join(\NumberInputTask.id, to: \Task.id, method: .left)
            .join(\FlashCardTask.id, to: \Task.id, method: .left)
            .decode(data: MultipleChoiseTaskKey.self, "MultipleChoiseTask")
            .alsoDecode(NumberInputTaskKey.self, "NumberInputTask")
            .first()
            .unwrap(or: Abort(.internalServerError))
            .map { (multiple, number) in

                if multiple.isMultipleSelect != nil {
                    return "tasks/multiple-choise"
                } else if number.correctAnswer != nil {
                    return "tasks/input"
                } else {
                    return "tasks/flash-card"
                }
        }
    }

    public static func getNumberOfTasks(in subtopicIDs: Subtopic.ID..., on conn: DatabaseConnectable) -> Future<Int> {
        return Task.query(on: conn)
            .filter(\.subtopicId ~~ subtopicIDs)
            .count()
    }

    public static func getTaskCreators(on conn: PostgreSQLConnection) -> Future<[TaskCreators]> {

        return conn.select()
            .column(.count(.all, as: "taskCount"))
            .column(.keyPath(\User.id, as: "userID"))
            .column(.keyPath(\User.name, as: "userName"))
            .from(Task.self)
            .join(\Task.creatorId, to: \User.id)
            .groupBy(\User.id)
            .all(decoding: TaskCreators.self)
    }
    
    public static func taskType(with id: Task.ID, on conn: PostgreSQLConnection) -> Future<(Task, MultipleChoiseTask?, NumberInputTask?)?> {
        
        return conn.select()
            .all(table: Task.self)
            .all(table: MultipleChoiseTask.self)
            .all(table: NumberInputTask.self)
            .from(Task.self)
            .where(\Task.id == id)
            .join(\Task.id, to: \MultipleChoiseTask.id, method: .left)
            .join(\Task.id, to: \NumberInputTask.id, method: .left)
            .first(decoding: Task.self, MultipleChoiseTask?.self, NumberInputTask?.self)
    }
}


public struct TaskCreators: Content {

    public let userID: User.ID

    public let userName: String

    public let taskCount: Int
}
