//
//  FlashCardRepository.swift
//  KognitaCore
//
//  Created by Mats Mollestad on 11/04/2019.
//

import FluentPostgreSQL
import Vapor

public class FlashCardRepository {

    public static let shared = FlashCardRepository()

    public func create(with content: FlashCardTaskCreateContent, user: User, conn: DatabaseConnectable) throws -> Future<Task> {
        try content.validate()

        return Topic.find(content.topicId, on: conn)
            .unwrap(or: TaskCreationError.invalidTopic)
            .flatMap { topic in
                conn.transaction(on: .psql) { conn in
                    try Task(content: content, topic: topic, creator: user)
                        .create(on: conn)
                        .flatMap { task in
                            try FlashCardTask(task: task)
                                .create(on: conn)
                                .transform(to: task)
                    }
                }
        }
    }

    public func importTask(from task: Task, in topic: Topic, on conn: DatabaseConnectable) throws -> Future<Void> {
        task.id = nil
        task.creatorId = 1
        try task.topicId = topic.requireID()
        return task.create(on: conn).flatMap { task in
            try FlashCardTask(task: task)
                .create(on: conn)
                .transform(to: ())
        }
    }

    public func edit(task flashCard: FlashCardTask, with content: FlashCardTaskCreateContent, user: User, conn: DatabaseConnectable) throws -> Future<Task> {
        guard user.isCreator else {
            throw Abort(.forbidden)
        }
        guard let task = flashCard.task else {
            throw Abort(.internalServerError)
        }
        try content.validate()
        return try FlashCardRepository.shared
            .create(with: content, user: user, conn: conn)
            .flatMap { newTask in
                task.get(on: conn)
                    .flatMap { task in
                        task.deletedAt = Date()
                        task.editedTaskID = newTask.id
                        return task
                            .save(on: conn)
                            .transform(to: newTask)
                }
        }
    }

    public func delete(task flashCard: FlashCardTask, user: User, conn: DatabaseConnectable) throws -> Future<Void> {

        guard user.isCreator else {
            throw Abort(.forbidden)
        }
        guard let task = flashCard.task else {
            throw Abort(.internalServerError)
        }
        return task.get(on: conn)
            .flatMap { task in
                return task.delete(on: conn)
        }
    }

    public func get(task flashCard: FlashCardTask, conn: DatabaseConnectable) throws -> Future<Task> {
        guard let task = flashCard.task else {
            throw Abort(.internalServerError)
        }
        return task.get(on: conn)
    }

    public func getCollection(conn: DatabaseConnectable) -> Future<[Task]> {
        return FlashCardTask.query(on: conn)
            .join(\FlashCardTask.id, to: \Task.id)
            .decode(Task.self)
            .all()
    }


    public func content(for flashCard: FlashCardTask, on conn: DatabaseConnectable) -> Future<TaskPreviewContent> {

        return Task.query(on: conn)
            .filter(\Task.id == flashCard.id)
            .join(\Topic.id, to: \Task.topicId)
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
                    actionDescription: NumberInputTask.actionDescription
                )
        }
    }
}
