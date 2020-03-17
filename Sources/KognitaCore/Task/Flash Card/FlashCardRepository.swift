//
//  FlashCardRepository.swift
//  KognitaCore
//
//  Created by Mats Mollestad on 11/04/2019.
//

import FluentPostgreSQL
import Vapor


public protocol FlashCardTaskRepository:
    CreateModelRepository,
    UpdateModelRepository,
    DeleteModelRepository
    where
    Model           == FlashCardTask,
    CreateData      == FlashCardTask.Create.Data,
    CreateResponse  == FlashCardTask.Create.Response,
    UpdateData      == FlashCardTask.Edit.Data,
    UpdateResponse  == FlashCardTask.Edit.Response
{
    static func importTask(
        from task: Task.BetaFormat,
        in subtopic: Subtopic,
        on conn: DatabaseConnectable
    ) throws -> EventLoopFuture<Void>

    static func modifyContent(forID taskID: Task.ID, on conn: DatabaseConnectable) throws -> EventLoopFuture<FlashCardTask.ModifyContent>
}


extension FlashCardTask {
    
    public final class DatabaseRepository: FlashCardTaskRepository {}
}

extension FlashCardTask.DatabaseRepository {
    
    public static func create(from content: FlashCardTask.Create.Data, by user: User?, on conn: DatabaseConnectable) throws -> EventLoopFuture<Task> {
        
        guard let user = user else {
            throw Abort(.unauthorized)
        }
        try content.validate()
        return Subtopic.DatabaseRepository
            .find(content.subtopicId, on: conn)
            .unwrap(or: Task.Create.Errors.invalidTopic)
            .flatMap { subtopic in

                conn.transaction(on: .psql) { conn in

                    try Task.Repository
                        .create(
                            from: .init(
                                content: content,
                                subtopicID: subtopic.requireID(),
                                solution: content.solution
                            ),
                            by: user,
                            on: conn
                    )
                        .flatMap { task in

                            try FlashCardTask(task: task)
                                .create(on: conn)
                                .transform(to: task)
                    }
                }
        }
    }
    
    public static func update(model flashCard: FlashCardTask, to content: FlashCardTask.Create.Data, by user: User, on conn: DatabaseConnectable) throws -> EventLoopFuture<Task> {

        guard let task = flashCard.task else {
            throw Abort(.internalServerError)
        }
        try content.validate()

        return try User.DatabaseRepository
            .isModerator(user: user, taskID: flashCard.requireID(), on: conn)
            .flatMap {
                try update(task: task, to: content, by: user, on: conn)
        }
        .catchFlatMap { _ in
            task.get(on: conn).flatMap { newTask in
                guard try newTask.creatorID == user.requireID() else {
                    throw Abort(.forbidden)
                }
                return try update(task: task, to: content, by: user, on: conn)
            }
        }
    }

    private static func update(task: Parent<FlashCardTask, Task>, to content: FlashCardTask.Create.Data, by user: User, on conn: DatabaseConnectable) throws -> EventLoopFuture<Task> {

        conn.transaction(on: .psql) { conn in
            try FlashCardTask.DatabaseRepository
                .create(from: content, by: user, on: conn)
                .flatMap { newTask in

                    task.get(on: conn)
                        .flatMap { task in
                            task.deletedAt = Date()  // Equilent to .delete(on: conn)
                            task.editedTaskID = newTask.id
                            return task
                                .save(on: conn)
                                .transform(to: newTask)
                    }
            }
        }
    }

    public static func delete(model flashCard: FlashCardTask, by user: User?, on conn: DatabaseConnectable) throws -> EventLoopFuture<Void> {

        guard let user = user else {
            throw Abort(.unauthorized)
        }

        return try User.DatabaseRepository
            .isModerator(user: user, taskID: flashCard.requireID(), on: conn)
            .map { true }
            .catchMap { _ in false }
            .flatMap { isModerator in

                guard let task = flashCard.task else {
                    throw Abort(.internalServerError)
                }
                return task.get(on: conn)
                    .flatMap { task in
                        
                        guard isModerator || task.creatorID == user.id else {
                            throw Abort(.forbidden)
                        }
                        return task.delete(on: conn)
                }
        }
    }

    public static func importTask(from task: Task.BetaFormat, in subtopic: Subtopic, on conn: DatabaseConnectable) throws -> EventLoopFuture<Void> {

        return try Task(
            subtopicID: subtopic.requireID(),
            description: task.description,
            question: task.question,
            creatorID: 1
        )
            .create(on: conn)
            .flatMap { savedTask in

                try FlashCardTask(
                    taskId: savedTask.requireID()
                )
                    .create(on: conn)
                    .flatMap { _ in
                        if let solution = task.solution {
                            return try TaskSolution(
                                data: TaskSolution.Create.Data(
                                    solution: solution,
                                    presentUser: true,
                                    taskID: savedTask.requireID()
                                ),
                                creatorID: 1
                            )
                                .create(on: conn)
                                .transform(to: ())
                        } else {
                            return conn.future()
                        }
                }
        }
    }

    public static func get(task flashCard: FlashCardTask, conn: DatabaseConnectable) throws -> EventLoopFuture<Task> {
        guard let task = flashCard.task else {
            throw Abort(.internalServerError)
        }
        return task.get(on: conn)
    }

    public static func getCollection(conn: DatabaseConnectable) -> Future<[Task]> {
        return FlashCardTask.query(on: conn)
            .join(\FlashCardTask.id, to: \Task.id)
            .decode(Task.self)
            .all()
    }


    public static func content(for flashCard: FlashCardTask, on conn: DatabaseConnectable) -> EventLoopFuture<TaskPreviewContent> {

        return Task.query(on: conn, withSoftDeleted: true)
            .filter(\Task.id == flashCard.id)
            .join(\Subtopic.id, to: \Task.subtopicID)
            .join(\Topic.id, to: \Subtopic.topicId)
            .join(\Subject.id, to: \Topic.subjectId)
            .alsoDecode(Topic.self)
            .alsoDecode(Subject.self)
            .first()
            .unwrap(or: Abort(.internalServerError))
            .map { preview in
                TaskPreviewContent(
                    subject: preview.1,
                    topic: preview.0.1,
                    task: preview.0.0,
                    actionDescription: FlashCardTask.actionDescriptor
                )
        }
    }

    public static func createAnswer(for task: FlashCardTask, with submit: FlashCardTask.Submit, on conn: DatabaseConnectable) -> EventLoopFuture<TaskAnswer> {
        TaskAnswer()
            .create(on: conn)
            .flatMap { answer in
                try FlashCardAnswer(
                    answerID: answer.requireID(),
                    taskID: task.requireID(),
                    answer: submit.answer
                )
                .create(on: conn)
                .transform(to: answer)
        }
    }

    public static func modifyContent(forID taskID: Task.ID, on conn: DatabaseConnectable) throws -> EventLoopFuture<FlashCardTask.ModifyContent> {

        Task.query(on: conn)
            .join(\FlashCardTask.id, to: \Task.id)
            .join(\TaskSolution.taskID, to: \Task.id)
            .filter(\Task.id == taskID)
            .alsoDecode(TaskSolution.self)
            .first()
            .unwrap(or: Abort(.internalServerError))
            .flatMap { taskInfo in

                Subject.query(on: conn)
                    .join(\Topic.subjectId, to: \Subject.id)
                    .join(\Subtopic.topicId, to: \Topic.id)
                    .filter(\Subtopic.id == taskInfo.0.subtopicID)
                    .first()
                    .unwrap(or: Abort(.internalServerError))
                    .flatMap { subject in

                        try Topic.DatabaseRepository.getTopicResponses(in: subject, conn: conn)
                            .map { topics in

                                FlashCardTask.ModifyContent(
                                    task: Task.ModifyContent(
                                        task: taskInfo.0,
                                        solution: taskInfo.1
                                    ),
                                    subject: Subject.Overview(subject: subject),
                                    topics: topics
                                )
                        }
                }
        }
    }
}
