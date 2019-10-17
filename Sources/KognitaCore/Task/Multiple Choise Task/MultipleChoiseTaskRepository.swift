//
//  MultipleChoiseTaskRepository.swift
//  KognitaCore
//
//  Created by Mats Mollestad on 11/04/2019.
//

import FluentPostgreSQL
import Vapor

extension MultipleChoiseTask {
    
    public final class Repository : KognitaCRUDRepository {
        
        public typealias Model = MultipleChoiseTask
        
        public static var shared = Repository()
    }
}


extension MultipleChoiseTask.Repository {
    
    public static func create(from content: MultipleChoiseTask.Create.Data, by user: User?, on conn: DatabaseConnectable) throws -> EventLoopFuture<MultipleChoiseTask> {
        guard let user = user, user.isCreator else {
            throw Abort(.forbidden)
        }
        try content.validate()
        
        return Subtopic.Repository
            .find(content.subtopicId, on: conn)
            .unwrap(or: Task.Create.Errors.invalidTopic)
            .flatMap { subtopic in
                
                conn.transaction(on: .psql) { conn in
                    
                    try Task.Repository
                        .create(from: .init(content: content, subtopic: subtopic), by: user, on: conn)
                        .flatMap { (task) in
                            
                            try MultipleChoiseTask(
                                isMultipleSelect: content.isMultipleSelect,
                                task: task
                            )
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
    
    public static func edit(_ multiple: MultipleChoiseTask, to content: MultipleChoiseTask.Edit.Data, by user: User, on conn: DatabaseConnectable) throws -> EventLoopFuture<MultipleChoiseTask> {
        
        guard user.isCreator else {
            throw Abort(.forbidden)
        }
        guard let task = multiple.task else {
            throw Abort(.internalServerError)
        }

        return try MultipleChoiseTask.Repository
            .create(from: content, by: user, on: conn)
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
    
    public static func delete(_ multiple: MultipleChoiseTask.Repository.Model, by user: User?, on conn: DatabaseConnectable) throws -> EventLoopFuture<Void> {
        guard let user = user, user.isCreator else {
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

    public static func importTask(from taskContent: MultipleChoiseTask.Data, in subtopic: Subtopic, on conn: DatabaseConnectable) throws -> Future<Void> {
        taskContent.task.id = nil
        taskContent.task.creatorId = 1
        try taskContent.task.subtopicId = subtopic.requireID()
        return taskContent.task.create(on: conn).flatMap { task in
            try MultipleChoiseTask(isMultipleSelect: taskContent.isMultipleSelect, taskID: task.requireID())
                .create(on: conn)
        }.flatMap { task in
            try taskContent.choises
                .map { choise in
                    choise.id = nil
                    try choise.taskId = task.requireID()
                    return choise.create(on: conn)
                        .transform(to: ())
            }
            .flatten(on: conn)
        }
    }

    public static func get(task: MultipleChoiseTask, conn: DatabaseConnectable) throws -> Future<MultipleChoiseTask.Data> {

        return try task.choises
            .query(on: conn)
            .join(\Task.id, to: \MultipleChoiseTaskChoise.taskId)
            .alsoDecode(Task.self)
            .all()
            .map { choises in
                guard let first = choises.first else {
                    throw Abort(.noContent, reason: "Missing choises in task")
                }
                return MultipleChoiseTask.Data(
                    task: first.1,
                    multipleTask: task,
                    choises: choises.map { $0.0 }.shuffled())
        }
    }

    public static func content(for multiple: MultipleChoiseTask, on conn: DatabaseConnectable) throws -> Future<(TaskPreviewContent, MultipleChoiseTask.Data)> {

        return try multiple
            .content(on: conn)
            .flatMap { content in

                Task.query(on: conn)
                    .filter(\Task.id == multiple.id)
                    .join(\Subtopic.id, to: \Task.subtopicId)
                    .join(\Topic.id, to: \Subtopic.topicId)
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

    static func evaluate(_ submit: MultipleChoiseTask.Submit, for task: MultipleChoiseTask, on conn: DatabaseConnectable) throws -> Future<PracticeSessionResult<[MultipleChoiseTaskChoise.Result]>> {

        return try task.choises
            .query(on: conn)
            .filter(\.isCorrect == true)
            .all()
            .map { correctChoises in

                var numberOfCorrect = 0
                var numberOfIncorrect = 0
                var missingAnswers = correctChoises
                var results = [MultipleChoiseTaskChoise.Result]()

                for choise in submit.choises {
                    if let index = missingAnswers.firstIndex(where: { $0.id == choise }) {
                        numberOfCorrect += 1
                        missingAnswers.remove(at: index)
                        results.append(.init(id: choise, isCorrect: true))
                    } else {
                        numberOfIncorrect += 1
                        results.append(.init(id: choise, isCorrect: false))
                    }
                }
                try results += missingAnswers.map {
                    try .init(id: $0.requireID(), isCorrect: true)
                }

                let score = Double(numberOfCorrect) / Double(correctChoises.count)

                return PracticeSessionResult(
                    result: results,
                    score: score,
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
