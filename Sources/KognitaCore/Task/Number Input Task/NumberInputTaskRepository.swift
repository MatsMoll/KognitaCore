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
    public func create(with content: NumberInputTask.Create.Data, user: User, conn: DatabaseConnectable) throws -> Future<NumberInputTask> {
        guard user.isCreator else {
            throw Abort(.forbidden)
        }
        try content.validate()
        return Subtopic.find(content.subtopicId, on: conn)
            .unwrap(or: TaskCreationError.invalidTopic)
            .flatMap { subtopic in
                conn.transaction(on: .psql) { conn in
                    try Task(content: content, subtopic: subtopic, creator: user)
                        .create(on: conn)
                        .flatMap { (task) in
                            try NumberInputTask(content: content, task: task)
                                .create(on: conn)
                        }
                }
        }
    }

    public func importTask(from taskContent: NumberInputTask.Data, in subtopic: Subtopic, on conn: DatabaseConnectable) throws -> Future<Void> {
        taskContent.task.id = nil
        taskContent.task.creatorId = 1
        try taskContent.task.subtopicId = subtopic.requireID()
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

    public func edit(task number: NumberInputTask, with content: NumberInputTask.Create.Data, user: User, conn: DatabaseConnectable) throws -> Future<NumberInputTask> {
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

    public func get(task number: NumberInputTask, conn: DatabaseConnectable) throws -> Future<NumberInputTask.Data> {
        guard let task = number.task else {
            throw Abort(.internalServerError)
        }
        return task.get(on: conn)
            .map { task in
                NumberInputTask.Data(task: task, input: number)
        }
    }

    public func content(for input: NumberInputTask, on conn: DatabaseConnectable) throws -> Future<(TaskPreviewContent, NumberInputTask)> {

        return Task.query(on: conn)
            .filter(\Task.id == input.id)
            .join(\Subtopic.id, to: \Task.subtopicId)
            .join(\Topic.id, to: \Subtopic.topicId)
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

    public func evaluate(_ answer: NumberInputTask.Submit.Data, for task: NumberInputTask) -> PracticeSessionResult<NumberInputTask.Submit.Response> {
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
