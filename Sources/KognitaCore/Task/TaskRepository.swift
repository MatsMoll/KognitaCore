//
//  TaskRepository.swift
//  Async
//
//  Created by Mats Mollestad on 12/04/2019.
//

import FluentPostgreSQL
import FluentSQL
import Vapor

public class TaskRepository {

    public static let shared = TaskRepository()

    public func getTasks(in subject: Subject, conn: DatabaseConnectable) throws -> Future<[TaskContent]> {

        return try subject.topics
            .query(on: conn)
            .join(\Task.topicId, to: \Topic.id)
            .filter(\Task.isOutdated == false)
            .join(\User.id, to: \Task.creatorId)
            .alsoDecode(Task.self)
            .alsoDecode(User.self)
            .all().flatMap { tasks in
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

    public func getTasks<A>(where filter: FilterOperator<PostgreSQLDatabase, A>, conn: DatabaseConnectable) throws -> Future<[TaskContent]> {

        return Task.query(on: conn)
            .join(\Topic.id, to: \Task.topicId)
            .join(\Subject.id, to: \Topic.subjectId)
            .join(\User.id, to: \Task.creatorId)
            .filter(filter)
            .alsoDecode(Topic.self)
            .alsoDecode(Subject.self)
            .alsoDecode(User.self)
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

    public func getTaskTypePath(for id: Task.ID, conn: DatabaseConnectable) throws -> Future<String> {

        return Task.query(on: conn)
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

    public func getNumberOfTasks(in topicIDs: Topic.ID..., on conn: DatabaseConnectable) -> Future<Int> {
        return Task.query(on: conn)
            .filter(\.isOutdated == false)
            .filter(\.topicId ~~ topicIDs)
            .count()
    }

    public func getTaskCreators(on conn: PostgreSQLConnection) -> Future<[TaskCreators]> {

        return conn.select()
            .column(.count(.all, as: "taskCount"))
            .column(.keyPath(\User.id, as: "userID"))
            .column(.keyPath(\User.name, as: "userName"))
            .from(Task.self)
            .join(\Task.creatorId, to: \User.id)
            .groupBy(\User.id)
            .all(decoding: TaskCreators.self)
    }
}


public struct TaskCreators: Content {

    public let userID: User.ID

    public let userName: String

    public let taskCount: Int
}
