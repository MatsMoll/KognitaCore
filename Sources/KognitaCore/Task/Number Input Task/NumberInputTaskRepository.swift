//
//  NumberInputTaskRepository.swift
//  KognitaCore
//
//  Created by Mats Mollestad on 11/04/2019.
//

import FluentPostgreSQL
import Vapor


public class NumberInputTaskRepository {

    public static let shared = NumberInputTaskRepository()

    /// Creates and saves a multiple choise task
    ///
    /// - Parameters:
    ///     - content:      The content to assign the task
    ///     - user:         The user creating the task
    ///     - conn:         A connection to the database
    ///
    /// - Returns:          The task id of the created task
    public func create(with content: NumberInputTaskCreateContent, user: User, conn: DatabaseConnectable) throws -> Future<NumberInputTask> {
        guard user.isCreator else {
            throw Abort(.forbidden)
        }
        try content.validate()
        return Topic.find(content.topicId, on: conn)
            .unwrap(or: TaskCreationError.invalidTopic)
            .flatMap { topic in
                conn.transaction(on: .psql) { conn in
                    try Task(content: content, topic: topic, creator: user)
                        .create(on: conn)
                        .flatMap { (task) in
                            try NumberInputTask(content: content, task: task)
                                .create(on: conn)
                        }
                }
        }
    }

    public func importTask(from taskContent: NumberInputTaskContent, in topic: Topic, on conn: DatabaseConnectable) throws -> Future<Void> {
        taskContent.task.id = nil
        taskContent.task.creatorId = 1
        try taskContent.task.topicId = topic.requireID()
        return taskContent.task.create(on: conn).flatMap { task in
            try NumberInputTask(correctAnswer: taskContent.input.correctAnswer, unit: taskContent.input.unit, taskId: task.requireID())
                .create(on: conn)
                .transform(to: ())
        }
    }

    public func delete(task number: NumberInputTask, user: User, conn: DatabaseConnectable) throws -> Future<Void> {
        guard user.isCreator else {
            throw Abort(.forbidden)
        }
        guard let task = number.task else {
            throw Abort(.internalServerError)
        }
        return task.get(on: conn)
            .flatMap { task in
                return task.delete(on: conn)
        }
    }

    public func edit(task number: NumberInputTask, with content: NumberInputTaskCreateContent, user: User, conn: DatabaseConnectable) throws -> Future<NumberInputTask> {
        guard user.isCreator else {
            throw Abort(.forbidden)
        }
        guard let task = number.task else {
            throw Abort(.internalServerError)
        }
        return try NumberInputTaskRepository.shared
            .create(with: content, user: user, conn: conn)
            .flatMap { newTask in
                task.get(on: conn)
                    .flatMap { task in
                        task.editedTaskID = newTask.id
                        task.deletedAt = Date()  // Equilent to .delete(on: conn)
                        return task
                            .save(on: conn)
                            .transform(to: newTask)
                }
        }
    }

    public func get(task number: NumberInputTask, conn: DatabaseConnectable) throws -> Future<NumberInputTaskContent> {
        guard let task = number.task else {
            throw Abort(.internalServerError)
        }
        return task.get(on: conn)
            .map { task in
            NumberInputTaskContent(task: task, input: number)
        }
    }

    public func content(for input: NumberInputTask, on conn: DatabaseConnectable) throws -> Future<(TaskPreviewContent, NumberInputTask)> {

        return Task.query(on: conn)
            .filter(\Task.id == input.id)
            .join(\Topic.id, to: \Task.topicId)
            .join(\Subject.id, to: \Topic.subjectId)
            .alsoDecode(Topic.self)
            .alsoDecode(Subject.self)
            .first()
            .unwrap(or: Abort(.internalServerError))
            .map { preview in

                (
                    TaskPreviewContent(
                        subject: preview.1,
                        topic: preview.0.1,
                        task: preview.0.0,
                        actionDescription: NumberInputTask.actionDescription
                    ),
                    input
                )
        }
    }

    public func evaluate(_ answer: NumberInputTaskSubmit, for task: NumberInputTask) -> PracticeSessionResult<NumberInputTaskSubmitResponse> {
        let wasCorrect = task.correctAnswer == answer.answer
        return PracticeSessionResult(
            result: .init(
                correctAnswer: task.correctAnswer,
                wasCorrect: wasCorrect
            ),
            unforgivingScore: wasCorrect ? 1 : 0,
            forgivingScore: wasCorrect ? 1 : 0,
            progress: 0
        )
    }
}
