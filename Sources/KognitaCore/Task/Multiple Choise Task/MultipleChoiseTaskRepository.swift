//
//  MultipleChoiseTaskRepository.swift
//  KognitaCore
//
//  Created by Mats Mollestad on 11/04/2019.
//

import FluentPostgreSQL
import Vapor

public protocol MultipleChoiseTaskRepository:
    CreateModelRepository,
    UpdateModelRepository,
    DeleteModelRepository
    where
    Model           == MultipleChoiseTask,
    CreateData      == MultipleChoiseTask.Create.Data,
    CreateResponse  == MultipleChoiseTask.Create.Response,
    UpdateData      == MultipleChoiseTask.Edit.Data,
    UpdateResponse  == MultipleChoiseTask.Edit.Response
{}

extension MultipleChoiseTask {
    public final class DatabaseRepository: MultipleChoiseTaskRepository {}
}


extension MultipleChoiseTask.DatabaseRepository {
    
    public static func create(
        from content: MultipleChoiseTask.Create.Data,
        by user: User?,
        on conn: DatabaseConnectable
    ) throws -> EventLoopFuture<MultipleChoiseTask> {

        guard let user = user, user.isCreator else {
            throw Abort(.forbidden)
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
                            on: conn)
                        .flatMap { task in

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

    public static func update(
        model: MultipleChoiseTask,
        to data: MultipleChoiseTask.Edit.Data,
        by user: User,
        on conn: DatabaseConnectable
    ) throws -> EventLoopFuture<MultipleChoiseTask> {

           guard user.isCreator else {
               throw Abort(.forbidden)
           }
           guard let task = model.task else {
               throw Abort(.internalServerError)
           }

           return try MultipleChoiseTask.DatabaseRepository
               .create(from: data, by: user, on: conn)
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

    public static func delete(
        model: MultipleChoiseTask,
        by user: User?,
        on conn: DatabaseConnectable
    ) throws -> EventLoopFuture<Void> {
        guard let user = user, user.isCreator else {
           throw Abort(.forbidden)
       }
       guard let task = model.task else {
           throw Abort(.internalServerError)
       }
       return task.get(on: conn)
           .flatMap { task in
               return task
                   .delete(on: conn)
                   .transform(to: ())
       }
    }

    public static func importTask(
        from taskContent: MultipleChoiseTask.BetaFormat,
        in subtopic: Subtopic,
        on conn: DatabaseConnectable
    ) throws -> EventLoopFuture<Void> {

        return try Task(
            subtopicID: subtopic.requireID(),
            description: taskContent.task.description,
            question: taskContent.task.question,
            creatorID: 1
        )
            .create(on: conn)
            .flatMap { savedTask -> EventLoopFuture<MultipleChoiseTask> in

                if let solution = taskContent.task.solution {
                    return try TaskSolution(
                        data: TaskSolution.Create.Data(
                            solution: solution,
                            presentUser: true,
                            taskID: savedTask.requireID()),
                        creatorID: 1
                    )
                        .create(on: conn)
                        .flatMap { _ in
                            try MultipleChoiseTask(
                                isMultipleSelect: taskContent.isMultipleSelect,
                                taskID: savedTask.requireID()
                            )
                                .create(on: conn)
                    }
                } else {
                    return try MultipleChoiseTask(
                        isMultipleSelect: taskContent.isMultipleSelect,
                        taskID: savedTask.requireID()
                    )
                        .create(on: conn)
                }
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

    public static func get(
        task: MultipleChoiseTask,
        conn: DatabaseConnectable
    ) throws -> EventLoopFuture<MultipleChoiseTask.Data> {

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

    public static func content(
        for multiple: MultipleChoiseTask,
        on conn: DatabaseConnectable
    ) throws -> EventLoopFuture<(TaskPreviewContent, MultipleChoiseTask.Data)> {

        return try multiple
            .content(on: conn)
            .flatMap { content in

                Task.query(on: conn, withSoftDeleted: true)
                    .filter(\Task.id == multiple.id)
                    .join(\Subtopic.id, to: \Task.subtopicID)
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

    /// Evaluates the submited data and returns a score indicating *how much correct* the answer was
    static func evaluate(
        _ choises: [MultipleChoiseTaskChoise.ID],
        for task: MultipleChoiseTask,
        on conn: DatabaseConnectable
    ) throws -> EventLoopFuture<TaskSessionResult<[MultipleChoiseTaskChoise.Result]>> {

        return try task.choises
            .query(on: conn)
            .filter(\.isCorrect == true)
            .all()
            .map { correctChoises in

                try evaluate(choises, agenst: correctChoises)
        }
    }

    /// Evaluates the submited data and returns a score indicating *how much correct* the answer was
    static func evaluate(
        _ choises: [MultipleChoiseTaskChoise.ID],
        agenst correctChoises: [MultipleChoiseTaskChoise]
    ) throws -> TaskSessionResult<[MultipleChoiseTaskChoise.Result]> {

        var numberOfCorrect = 0
        var numberOfIncorrect = 0
        var missingAnswers = correctChoises.filter({ $0.isCorrect })
        var results = [MultipleChoiseTaskChoise.Result]()

        for choise in choises {
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

        return TaskSessionResult(
            result: results,
            score: score,
            progress: 0
        )
    }

    public static func create(
        answer submit: MultipleChoiseTask.Submit,
        on conn: DatabaseConnectable
    ) -> EventLoopFuture<[TaskAnswer]> {
        
        submit.choises.map { choise in
            createAnswer(choiseID: choise, on: conn)
        }
        .flatten(on: conn)
    }

    public static func createAnswer(choiseID: MultipleChoiseTaskChoise.ID, on conn: DatabaseConnectable) -> EventLoopFuture<TaskAnswer> {
        TaskAnswer()
            .save(on: conn)
            .flatMap { answer in
                try MultipleChoiseTaskAnswer(answerID: answer.requireID(), choiseID: choiseID)
                    .create(on: conn)
                    .transform(to: answer)
        }
    }

    public static func correctChoisesFor(taskID: Task.ID, on conn: DatabaseConnectable) -> EventLoopFuture<[MultipleChoiseTaskChoise]> {
        MultipleChoiseTaskChoise.query(on: conn)
            .filter(\.taskId == taskID)
            .filter(\.isCorrect == true)
            .all()
    }
}


public struct TaskPreviewContent {
    public let subject: Subject
    public let topic: Topic
    public let task: Task
    public let actionDescription: String
}
