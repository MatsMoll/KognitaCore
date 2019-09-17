//
//  FlashCardRepository.swift
//  KognitaCore
//
//  Created by Mats Mollestad on 11/04/2019.
//

import FluentPostgreSQL
import Vapor

extension FlashCardTask {
    
    public final class Repository : KognitaCRUDRepository {
        
        public typealias Model = FlashCardTask
        
        public static var shared = Repository()
    }
}


extension FlashCardTask.Repository {
    
    public func create(from content: FlashCardTask.Create.Data, by user: User?, on conn: DatabaseConnectable) throws -> EventLoopFuture<Task> {
        
        guard let user = user, user.isCreator else {
            throw Abort(.forbidden)
        }
        try content.validate()

        return Subtopic.repository
            .find(content.subtopicId, on: conn)
            .unwrap(or: Task.Create.Errors.invalidTopic)
            .flatMap { subtopic in
                
                conn.transaction(on: .psql) { conn in
                    
                    try Task.repository
                        .create(from: .init(content: content, subtopic: subtopic), by: user, on: conn)
                        .flatMap { task in
                            
                            try FlashCardTask(task: task)
                                .create(on: conn)
                                .transform(to: task)
                    }
                }
        }
    }
    
    public func edit(_ flashCard: FlashCardTask, to content: FlashCardTask.Create.Data, by user: User, on conn: DatabaseConnectable) throws -> EventLoopFuture<Task> {
        guard user.isCreator else {
            throw Abort(.forbidden)
        }
        guard let task = flashCard.task else {
            throw Abort(.internalServerError)
        }
        try content.validate()
        return try FlashCardTask.repository
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
    
    public func delete(_ flashCard: FlashCardTask, by user: User?, on conn: DatabaseConnectable) throws -> EventLoopFuture<Void> {
        
        guard let user = user, user.isCreator else {
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

    public func importTask(from task: Task, in subtopic: Subtopic, on conn: DatabaseConnectable) throws -> Future<Void> {
        task.id = nil
        task.creatorId = 1
        try task.subtopicId = subtopic.requireID()
        return task.create(on: conn).flatMap { task in
            try FlashCardTask(task: task)
                .create(on: conn)
                .transform(to: ())
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
            .join(\Subtopic.id, to: \Task.subtopicId)
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
}
