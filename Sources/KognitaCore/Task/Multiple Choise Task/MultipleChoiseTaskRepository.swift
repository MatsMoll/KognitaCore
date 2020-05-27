//
//  MultipleChoiseTaskRepository.swift
//  KognitaCore
//
//  Created by Mats Mollestad on 11/04/2019.
//

import FluentSQL
import FluentPostgreSQL
import Vapor

public protocol MultipleChoiseTaskRepository: CreateModelRepository,
    UpdateModelRepository,
    DeleteModelRepository
    where
    Model           == MultipleChoiseTask,
    CreateData      == MultipleChoiseTask.Create.Data,
    CreateResponse  == MultipleChoiseTask.Create.Response,
    UpdateData      == MultipleChoiseTask.Edit.Data,
    UpdateResponse  == MultipleChoiseTask.Edit.Response {
    func modifyContent(forID taskID: Task.ID) throws -> EventLoopFuture<MultipleChoiseTask.ModifyContent>
    func create(answer submit: MultipleChoiseTask.Submit, sessionID: TaskSession.ID) -> EventLoopFuture<[TaskAnswer]>
    func evaluate(_ choises: [MultipleChoiseTaskChoise.ID], for task: MultipleChoiseTask) throws -> EventLoopFuture<TaskSessionResult<[MultipleChoiseTaskChoise.Result]>>
    func importTask(from taskContent: MultipleChoiseTask.BetaFormat, in subtopic: Subtopic) throws -> EventLoopFuture<Void>
    func createAnswer(choiseID: MultipleChoiseTaskChoise.ID, sessionID: TaskSession.ID) -> EventLoopFuture<TaskAnswer>
    func choisesFor(taskID: MultipleChoiseTask.ID) -> EventLoopFuture<[MultipleChoiseTaskChoise]>
    func correctChoisesFor(taskID: Task.ID) -> EventLoopFuture<[MultipleChoiseTaskChoise]>
    func evaluate(_ choises: [MultipleChoiseTaskChoise.ID], agenst correctChoises: [MultipleChoiseTaskChoise]) throws -> TaskSessionResult<[MultipleChoiseTaskChoise.Result]>
}

extension MultipleChoiseTask {
    public struct DatabaseRepository: MultipleChoiseTaskRepository, DatabaseConnectableRepository {

        typealias DatabaseModel = MultipleChoiseTask

        public let conn: DatabaseConnectable

        private var subtopicRepository: some SubtopicRepositoring { Subtopic.DatabaseRepository(conn: conn) }
        private var userRepository: some UserRepository { User.DatabaseRepository(conn: conn) }
        private var topicRepository: some TopicRepository { Topic.DatabaseRepository(conn: conn) }
        private var taskRepository: some TaskRepository { Task.DatabaseRepository(conn: conn) }
    }
}

extension MultipleChoiseTask.DatabaseRepository {

    public func create(from content: MultipleChoiseTask.Create.Data, by user: User?) throws -> EventLoopFuture<MultipleChoiseTask> {

        guard let user = user else {
            throw Abort(.unauthorized)
        }
        try content.validate()
        return subtopicRepository
            .find(content.subtopicId)
            .unwrap(or: Task.Create.Errors.invalidTopic)
            .flatMap { subtopic in

                self.conn.transaction(on: .psql) { conn in

                    try self
                        .taskRepository
                        .create(
                            from: .init(
                                content: content,
                                subtopicID: subtopic.id,
                                solution: content.solution
                            ),
                            by: user
                        )
                        .flatMap { task in

                            try MultipleChoiseTask(
                                isMultipleSelect: content.isMultipleSelect,
                                task: task
                            )
                                .create(on: conn)
                        }
                    .flatMap { (task) in
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

    public func update(model: MultipleChoiseTask, to data: MultipleChoiseTask.Edit.Data, by user: User) throws -> EventLoopFuture<MultipleChoiseTask> {

        guard let task = model.task else {
            throw Abort(.internalServerError)
        }
        return try userRepository
            .isModerator(user: user, taskID: model.requireID())
            .flatMap {
                try self.update(task: task, to: data, by: user)
        }
        .catchFlatMap { _ in
            task.get(on: self.conn).flatMap { taskModel in
                guard taskModel.creatorID == user.id else {
                    throw Abort(.forbidden)
                }
                return try self.update(task: task, to: data, by: user)
            }
        }
    }

    private func update(task: Parent<MultipleChoiseTask, Task>, to data: MultipleChoiseTask.Edit.Data, by user: User) throws -> EventLoopFuture<MultipleChoiseTask> {
        try self
            .create(from: data, by: user)
            .flatMap { newTask in

                task.get(on: self.conn)
                    .flatMap { task in
                        task.deletedAt = Date() // Equilent to .delete(on: conn)
                        task.editedTaskID = newTask.id
                        return task
                            .save(on: self.conn)
                            .transform(to: newTask)
                }
        }
    }

    public func delete(model: MultipleChoiseTask, by user: User?) throws -> EventLoopFuture<Void> {
        guard let user = user else {
            throw Abort(.unauthorized)
        }
        return try userRepository
            .isModerator(user: user, taskID: model.requireID())
            .map { true }
            .catchMap { _ in false }
            .flatMap { isModerator in

                guard let task = model.task else {
                    throw Abort(.internalServerError)
                }
                return task.get(on: self.conn)
                    .flatMap { task in

                        guard isModerator || task.creatorID == user.id else {
                            throw Abort(.forbidden)
                        }
                        return task
                            .delete(on: self.conn)
                            .transform(to: ())
                }
        }
    }

    public func importTask(from taskContent: MultipleChoiseTask.BetaFormat, in subtopic: Subtopic) throws -> EventLoopFuture<Void> {

        return Task(
            subtopicID: subtopic.id,
            description: taskContent.task.description,
            question: taskContent.task.question,
            creatorID: 1
        )
            .create(on: conn)
            .flatMap { savedTask -> EventLoopFuture<MultipleChoiseTask> in

                if let solution = taskContent.task.solution {
                    return try TaskSolution.DatabaseModel(
                        data: TaskSolution.Create.Data(
                            solution: solution,
                            presentUser: true,
                            taskID: savedTask.requireID()),
                        creatorID: 1
                    )
                        .create(on: self.conn)
                        .flatMap { _ in
                            try MultipleChoiseTask(
                                isMultipleSelect: taskContent.isMultipleSelect,
                                taskID: savedTask.requireID()
                            )
                                .create(on: self.conn)
                    }
                } else {
                    return try MultipleChoiseTask(
                        isMultipleSelect: taskContent.isMultipleSelect,
                        taskID: savedTask.requireID()
                    )
                        .create(on: self.conn)
                }
        }.flatMap { task in
            try taskContent.choises
                .map { choise in
                    choise.id = nil
                    try choise.taskId = task.requireID()
                    return choise.create(on: self.conn)
                        .transform(to: ())
            }
            .flatten(on: self.conn)
        }
    }

    public func get(task: MultipleChoiseTask) throws -> EventLoopFuture<MultipleChoiseTask.Data> {

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

    public func content(for multiple: MultipleChoiseTask) throws -> EventLoopFuture<(TaskPreviewContent, MultipleChoiseTask.Data)> {

        return try multiple
            .content(on: conn)
            .flatMap { content in

                Task.query(on: self.conn, withSoftDeleted: true)
                    .filter(\Task.id == multiple.id)
                    .join(\Subtopic.DatabaseModel.id, to: \Task.subtopicID)
                    .join(\Topic.DatabaseModel.id, to: \Subtopic.DatabaseModel.topicId)
                    .join(\Subject.DatabaseModel.id, to: \Topic.DatabaseModel.subjectId)
                    .alsoDecode(Topic.DatabaseModel.self)
                    .alsoDecode(Subject.DatabaseModel.self)
                    .first()
                    .unwrap(or: Abort(.internalServerError))
                    .map { preview in

                        // Returning a tupple
                        try (
                            TaskPreviewContent(
                                subject: preview.1.content(),
                                topic: preview.0.1.content(),
                                task: preview.0.0,
                                actionDescription: multiple.actionDescription
                            ),
                            content
                        )
                }
        }
    }

    /// Evaluates the submited data and returns a score indicating *how much correct* the answer was
    public func evaluate(_ choises: [MultipleChoiseTaskChoise.ID], for task: MultipleChoiseTask) throws -> EventLoopFuture<TaskSessionResult<[MultipleChoiseTaskChoise.Result]>> {

        return try task.choises
            .query(on: conn)
            .filter(\.isCorrect == true)
            .all()
            .map { correctChoises in
                try self.evaluate(choises, agenst: correctChoises)
        }
    }

    /// Evaluates the submited data and returns a score indicating *how much correct* the answer was
    public func evaluate(_ choises: [MultipleChoiseTaskChoise.ID], agenst correctChoises: [MultipleChoiseTaskChoise]) throws -> TaskSessionResult<[MultipleChoiseTaskChoise.Result]> {

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

    public func create(answer submit: MultipleChoiseTask.Submit, sessionID: TaskSession.ID) -> EventLoopFuture<[TaskAnswer]> {

        submit.choises.map { choise in
            self.createAnswer(choiseID: choise, sessionID: sessionID)
        }
        .flatten(on: conn)
    }

    public func createAnswer(choiseID: MultipleChoiseTaskChoise.ID, sessionID: TaskSession.ID) -> EventLoopFuture<TaskAnswer> {
        TaskAnswer()
            .save(on: conn)
            .flatMap { answer in
                try MultipleChoiseTaskAnswer(answerID: answer.requireID(), choiseID: choiseID)
                    .create(on: self.conn)
                    .transform(to: answer)
        }
        .flatMap { answer in
            try TaskSessionAnswer(sessionID: sessionID, taskAnswerID: answer.requireID())
                .save(on: self.conn)
                .transform(to: answer)
        }
    }

    public func correctChoisesFor(taskID: Task.ID) -> EventLoopFuture<[MultipleChoiseTaskChoise]> {
        MultipleChoiseTaskChoise.query(on: conn)
            .filter(\.taskId == taskID)
            .filter(\.isCorrect == true)
            .all()
    }

    public func modifyContent(forID taskID: Task.ID) throws -> EventLoopFuture<MultipleChoiseTask.ModifyContent> {

        return conn.databaseConnection(to: .psql)
            .flatMap { conn in

                conn.select()
                    .all(table: Task.self)
                    .all(table: MultipleChoiseTask.self)
                    .all(table: TaskSolution.DatabaseModel.self)
                    .from(Task.self)
                    .join(\Task.id, to: \MultipleChoiseTask.id)
                    .join(\Task.id, to: \TaskSolution.DatabaseModel.taskID)
                    .where(\Task.id, .equal, taskID)
                    .first(decoding: Task.self, MultipleChoiseTask.self, TaskSolution.DatabaseModel.self)
                    .unwrap(or: Abort(.badRequest))
                    .flatMap { taskContent in

                        MultipleChoiseTaskChoise.query(on: conn)
                            .filter(\MultipleChoiseTaskChoise.taskId, .equal, taskID)
                            .all()
                            .flatMap { choises in

                                Subject.DatabaseModel.query(on: conn)
                                    .join(\Topic.DatabaseModel.subjectId, to: \Subject.DatabaseModel.id)
                                    .join(\Subtopic.DatabaseModel.topicId, to: \Topic.DatabaseModel.id)
                                    .filter(\Subtopic.DatabaseModel.id, .equal, taskContent.0.subtopicID)
                                    .first()
                                    .unwrap(or: Abort(.internalServerError))
                                    .flatMap { subject in

                                        try self.topicRepository
                                            .getTopicResponses(in: subject.content())
                                            .map { topics in

                                                try MultipleChoiseTask.ModifyContent(
                                                    task: Task.ModifyContent(
                                                        task: taskContent.0,
                                                        solution: taskContent.2.solution
                                                    ),
                                                    subject: subject.content(),
                                                    topics: topics,
                                                    multiple: taskContent.1,
                                                    choises: choises.map { .init(choise: $0) }
                                                )
                                        }

                                }
                        }
                }
        }

    }

    public func choisesFor(taskID: MultipleChoiseTask.ID) -> EventLoopFuture<[MultipleChoiseTaskChoise]> {
        MultipleChoiseTaskChoise.query(on: conn, withSoftDeleted: true)
            .filter(\.taskId == taskID)
            .all()
    }
}

public struct TaskPreviewContent {
    public let subject: Subject
    public let topic: Topic
    public let task: Task
    public let actionDescription: String
}
