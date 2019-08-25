//
//  MultipleChoiseTaskRepository.swift
//  KognitaCore
//
//  Created by Mats Mollestad on 11/04/2019.
//

import FluentPostgreSQL
import Vapor


public class MultipleChoiseTaskRepository {

    public static let shared = MultipleChoiseTaskRepository()

    /// Creates and saves a multiple choise task
    ///
    /// - Parameters:
    ///     - content:      The content to assign the task
    ///     - user:         The user creating the task
    ///     - conn:         A connection to the database
    ///
    /// - Returns:          The task id of the created task
    public func create(with content: MultipleChoiseTaskCreationContent, user: User, conn: DatabaseConnectable) throws -> Future<MultipleChoiseTask> {
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
                            try MultipleChoiseTask(
                                isMultipleSelect: content.isMultipleSelect,
                                task: task)
                                .create(on: conn)
                        } .flatMap { (task) in
                            try content.choises.map { choise in
                                try MultipleChoiseTaskChoise(content: choise, task: task)
                                    .save(on: conn) // For some reason will .create(on: conn) throw a duplicate primary key error
                                }
                                .flatten(on: conn)
                                .transform(to: task)
                    }
                }
        }
    }

    public func importTask(from taskContent: MultipleChoiseTaskContent, in topic: Topic, on conn: DatabaseConnectable) throws -> Future<Void> {
        taskContent.task.id = nil
        taskContent.task.creatorId = 1
        try taskContent.task.topicId = topic.requireID()
        return taskContent.task.create(on: conn).flatMap { task in
            try MultipleChoiseTask(isMultipleSelect: taskContent.isMultipleSelect, taskID: task.requireID())
                .create(on: conn)
        }.flatMap { task in
            try taskContent.choises
                .map { choise in
                    try choise.taskId = task.requireID()
                    return choise.create(on: conn)
                        .transform(to: ())
            }
            .flatten(on: conn)
        }
    }

    public func delete(task multiple: MultipleChoiseTask, user: User, conn: DatabaseConnectable) throws -> Future<Void> {
        guard user.isCreator else {
            throw Abort(.forbidden)
        }
        guard let task = multiple.task else {
            throw Abort(.internalServerError)
        }
        return task.get(on: conn)
            .flatMap { task in
                return task
                    .delete(on: conn)
                    .transform(to: ())
        }
    }

    public func edit(task multiple: MultipleChoiseTask, with content: MultipleChoiseTaskCreationContent, user: User, conn: DatabaseConnectable) throws -> Future<MultipleChoiseTask> {
        guard user.isCreator else {
            throw Abort(.forbidden)
        }
        guard let task = multiple.task else {
            throw Abort(.internalServerError)
        }

        return try MultipleChoiseTaskRepository.shared
            .create(with: content, user: user, conn: conn)
            .flatMap { newTask in

                task.get(on: conn)
                    .flatMap { task in

                        task.deletedAt = Date() // Equilent to .delete(on: conn)
                        task.editedTaskID = newTask.id
                        return task
                            .save(on: conn)
                            .transform(to: newTask)
                }
            }
    }

    public func get(task: MultipleChoiseTask, conn: DatabaseConnectable) throws -> Future<MultipleChoiseTaskContent> {

        return try task.choises
            .query(on: conn)
            .join(\Task.id, to: \MultipleChoiseTaskChoise.taskId)
            .alsoDecode(Task.self)
            .all()
            .map { choises in
                guard let first = choises.first else {
                    throw Abort(.noContent, reason: "Missing choises in task")
                }
                return MultipleChoiseTaskContent(
                    task: first.1,
                    multipleTask: task,
                    choises: choises.map { $0.0 }.shuffled())
        }
    }

    public func content(for multiple: MultipleChoiseTask, on conn: DatabaseConnectable) throws -> Future<(TaskPreviewContent, MultipleChoiseTaskContent)> {

        return try multiple
            .content(on: conn)
            .flatMap { content in

                Task.query(on: conn)
                    .filter(\Task.id == multiple.id)
                    .join(\Topic.id, to: \Task.topicId)
                    .join(\Subject.id, to: \Topic.subjectId)
                    .alsoDecode(Topic.self)
                    .alsoDecode(Subject.self)
                    .first()
                    .unwrap(or: Abort(.internalServerError))
                    .map { preview in

                        // Returning a tupple
                        (
                            TaskPreviewContent(
                                subject: preview.1,
                                topic: preview.0.1,
                                task: preview.0.0,
                                actionDescription: multiple.actionDescription
                            ),
                            content
                        )
                }
        }
    }

    func evaluate(_ submit: MultipleChoiseTaskSubmit, for task: MultipleChoiseTask, on conn: DatabaseConnectable) throws -> Future<PracticeSessionResult<[MultipleChoiseTaskChoiseResult]>> {

        return try task.choises
            .query(on: conn)
            .filter(\.isCorrect == true)
            .all()
            .map { correctChoises in

                var numberOfCorrect = 0
                var numberOfIncorrect = 0
                var missingAnswers = correctChoises
                var results = [MultipleChoiseTaskChoiseResult]()

                for choise in submit.choises {
                    if let index = missingAnswers.firstIndex(where: { $0.id == choise }) {
                        numberOfCorrect += 1
                        missingAnswers.remove(at: index)
                        results.append(MultipleChoiseTaskChoiseResult(id: choise, isCorrect: true))
                    } else {
                        numberOfIncorrect += 1
                        results.append(MultipleChoiseTaskChoiseResult(id: choise, isCorrect: false))
                    }
                }
                try results += missingAnswers.map {
                    try MultipleChoiseTaskChoiseResult(id: $0.requireID(), isCorrect: true)
                }

                let forgivingScore = Double(numberOfCorrect) / Double(correctChoises.count)

                let unforgivingScore = ScoreEvaluater.shared.compress(
                        score: Double(numberOfCorrect - numberOfIncorrect),
                        range: Double(-correctChoises.count)...Double(correctChoises.count))

                return PracticeSessionResult(
                    result: results,
                    unforgivingScore: unforgivingScore,
                    forgivingScore: forgivingScore,
                    progress: 0
                )
        }
    }
}


public struct TaskPreviewContent {
    public let subject: Subject
    public let topic: Topic
    public let task: Task
    public let actionDescription: String
}
