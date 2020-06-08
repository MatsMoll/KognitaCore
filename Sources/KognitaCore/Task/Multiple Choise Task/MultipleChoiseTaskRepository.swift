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
    Model           == MultipleChoiceTask,
    CreateData      == MultipleChoiceTask.Create.Data,
    CreateResponse  == MultipleChoiceTask.Create.Response,
    UpdateData      == MultipleChoiceTask.Update.Data,
    UpdateResponse  == MultipleChoiceTask.Update.Response {
    func modifyContent(forID taskID: Task.ID) throws -> EventLoopFuture<MultipleChoiceTask.Details>
    func create(answer submit: MultipleChoiceTask.Submit, sessionID: TestSession.ID) -> EventLoopFuture<[TaskAnswer]>
    func evaluate(_ choises: [MultipleChoiseTaskChoise.ID], for taskID: MultipleChoiceTask.ID) throws -> EventLoopFuture<TaskSessionResult<[MultipleChoiseTaskChoise.Result]>>
    func importTask(from taskContent: MultipleChoiceTask.BetaFormat, in subtopic: Subtopic) throws -> EventLoopFuture<Void>
    func createAnswer(choiseID: MultipleChoiseTaskChoise.ID, sessionID: TestSession.ID) -> EventLoopFuture<TaskAnswer>
    func choisesFor(taskID: MultipleChoiceTask.ID) -> EventLoopFuture<[MultipleChoiseTaskChoise]>
    func correctChoisesFor(taskID: Task.ID) -> EventLoopFuture<[MultipleChoiseTaskChoise]>
    func evaluate(_ choises: [MultipleChoiseTaskChoise.ID], agenst correctChoises: [MultipleChoiseTaskChoise]) throws -> TaskSessionResult<[MultipleChoiseTaskChoise.Result]>
}

extension MultipleChoiceTask {
    public struct DatabaseRepository: MultipleChoiseTaskRepository, DatabaseConnectableRepository {

        public let conn: DatabaseConnectable

        private var subtopicRepository: some SubtopicRepositoring { Subtopic.DatabaseRepository(conn: conn) }
        private var userRepository: some UserRepository { User.DatabaseRepository(conn: conn) }
        private var topicRepository: some TopicRepository { Topic.DatabaseRepository(conn: conn) }
        private var taskRepository: some TaskRepository { Task.DatabaseRepository(conn: conn) }
    }
}

extension MultipleChoiceTask.DatabaseRepository {

    public func create(from content: MultipleChoiceTask.Create.Data, by user: User?) throws -> EventLoopFuture<MultipleChoiceTask> {

        guard let user = user else {
            throw Abort(.unauthorized)
        }
//        try content.validate()
        return subtopicRepository
            .find(content.subtopicId)
            .unwrap(or: Task.Create.Errors.invalidTopic)
            .flatMap { subtopic in

                self.conn.transaction(on: .psql) { conn in

                    try self
                        .taskRepository
                        .create(
                            from: Task.Create.Data(
                                content: content,
                                subtopicID: subtopic.id,
                                solution: content.solution
                            ),
                            by: user
                        )
                        .flatMap { task in

                            try MultipleChoiceTask.DatabaseModel(
                                isMultipleSelect: content.isMultipleSelect,
                                task: task
                            )
                                .create(on: conn)
                        }
                    .flatMap { (task) in
                        try content.choises.map { choise in
                            try MultipleChoiseTaskChoise(content: choise, taskID: task.requireID())
                                .save(on: conn) // For some reason will .create(on: conn) throw a duplicate primary key error
                            }
                            .flatten(on: conn)
                            .flatMap { _ in
                                try task.content(on: conn)
                        }
                    }
                }
        }
    }

    public func update(model: MultipleChoiceTask, to data: MultipleChoiceTask.Update.Data, by user: User) throws -> EventLoopFuture<MultipleChoiceTask> {

        return try userRepository
            .isModerator(user: user, taskID: model.id)
            .flatMap {
                try self.update(taskID: model.id, to: data, by: user)
        }
        .catchFlatMap { _ in
            Task.find(model.id, on: self.conn)
                .unwrap(or: Abort(.badRequest))
                .flatMap { taskModel in
                    guard taskModel.creatorID == user.id else {
                        throw Abort(.forbidden)
                    }
                    return try self.update(taskID: model.id, to: data, by: user)
            }
        }
    }

    private func update(taskID: Task.ID, to data: MultipleChoiceTask.Update.Data, by user: User) throws -> EventLoopFuture<MultipleChoiceTask> {
        try create(from: data, by: user)
            .flatMap { newTask in

                Task.find(taskID, on: self.conn)
                    .unwrap(or: Abort(.badRequest))
                    .flatMap { task in
                        task.deletedAt = Date() // Equilent to .delete(on: conn)
                        task.editedTaskID = newTask.id
                        return task
                            .save(on: self.conn)
                            .transform(to: newTask)
                }
        }
    }

    public func delete(model: MultipleChoiceTask, by user: User?) throws -> EventLoopFuture<Void> {
        guard let user = user else {
            throw Abort(.unauthorized)
        }
        return try userRepository
            .isModerator(user: user, taskID: model.id)
            .map { true }
            .catchMap { _ in false }
            .flatMap { isModerator in

                Task.find(model.id, on: self.conn)
                    .unwrap(or: Abort(.badRequest))
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

    public func importTask(from taskContent: MultipleChoiceTask.BetaFormat, in subtopic: Subtopic) throws -> EventLoopFuture<Void> {

        return Task(
            subtopicID: subtopic.id,
            description: taskContent.task.description,
            question: taskContent.task.question,
            creatorID: 1
        )
            .create(on: conn)
            .flatMap { savedTask -> EventLoopFuture<MultipleChoiceTask.DatabaseModel> in

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
                            try MultipleChoiceTask.DatabaseModel(
                                isMultipleSelect: taskContent.isMultipleSelect,
                                taskID: savedTask.requireID()
                            )
                                .create(on: self.conn)
                    }
                } else {
                    return try MultipleChoiceTask.DatabaseModel(
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

    public func get(task: MultipleChoiceTask) throws -> EventLoopFuture<MultipleChoiceTask> {

        MultipleChoiceTask.DatabaseModel.query(on: conn)
            .join(\MultipleChoiseTaskChoise.taskId, to: \MultipleChoiceTask.DatabaseModel.id)
            .join(\Task.id, to: \MultipleChoiseTaskChoise.taskId)
            .filter(\MultipleChoiceTask.DatabaseModel.id == task.id)
            .alsoDecode(Task.self)
            .alsoDecode(MultipleChoiseTaskChoise.self)
            .all()
            .map { choises in
                guard let first = choises.first else {
                    throw Abort(.noContent, reason: "Missing choises in task")
                }
                return MultipleChoiceTask(
                    task: first.0.1,
                    isMultipleSelect: first.0.0.isMultipleSelect,
                    choises: choises.map { $0.1 }.shuffled()
                )
        }
    }

    public func content(for multiple: MultipleChoiceTask) throws -> EventLoopFuture<(TaskPreviewContent, MultipleChoiceTask)> {

        throw Abort(.notImplemented)
//        return try multiple
//            .content(on: conn)
//            .flatMap { content in
//
//                Task.query(on: self.conn, withSoftDeleted: true)
//                    .filter(\Task.id == multiple.id)
//                    .join(\Subtopic.DatabaseModel.id, to: \Task.subtopicID)
//                    .join(\Topic.DatabaseModel.id, to: \Subtopic.DatabaseModel.topicId)
//                    .join(\Subject.DatabaseModel.id, to: \Topic.DatabaseModel.subjectId)
//                    .alsoDecode(Topic.DatabaseModel.self)
//                    .alsoDecode(Subject.DatabaseModel.self)
//                    .first()
//                    .unwrap(or: Abort(.internalServerError))
//                    .map { preview in
//
//                        // Returning a tupple
//                        try (
//                            TaskPreviewContent(
//                                subject: preview.1.content(),
//                                topic: preview.0.1.content(),
//                                task: preview.0.0,
//                                actionDescription: multiple.actionDescription
//                            ),
//                            content
//                        )
//                }
//        }
    }

    /// Evaluates the submited data and returns a score indicating *how much correct* the answer was
    public func evaluate(_ choises: [MultipleChoiseTaskChoise.ID], for taskID: MultipleChoiceTask.ID) throws -> EventLoopFuture<TaskSessionResult<[MultipleChoiseTaskChoise.Result]>> {

        return MultipleChoiseTaskChoise.query(on: conn)
            .filter(\.taskId == taskID)
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

    public func create(answer submit: MultipleChoiceTask.Submit, sessionID: TestSession.ID) -> EventLoopFuture<[TaskAnswer]> {

        submit.choises.map { choise in
            self.createAnswer(choiseID: choise, sessionID: sessionID)
        }
        .flatten(on: conn)
    }

    public func createAnswer(choiseID: MultipleChoiseTaskChoise.ID, sessionID: TestSession.ID) -> EventLoopFuture<TaskAnswer> {
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

    public func modifyContent(forID taskID: Task.ID) throws -> EventLoopFuture<MultipleChoiceTask.Details> {

        throw Abort(.notImplemented)
//        return conn.databaseConnection(to: .psql)
//            .flatMap { conn in
//
//                conn.select()
//                    .all(table: Task.self)
//                    .all(table: MultipleChoiceTask.DatabaseModel.self)
//                    .all(table: TaskSolution.DatabaseModel.self)
//                    .from(Task.self)
//                    .join(\Task.id, to: \MultipleChoiceTask.DatabaseModel.id)
//                    .join(\Task.id, to: \TaskSolution.DatabaseModel.taskID)
//                    .where(\Task.id, .equal, taskID)
//                    .first(decoding: Task.self, MultipleChoiceTask.DatabaseModel.self, TaskSolution.DatabaseModel.self)
//                    .unwrap(or: Abort(.badRequest))
//                    .flatMap { taskContent in
//
//                        MultipleChoiseTaskChoise.query(on: conn)
//                            .filter(\MultipleChoiseTaskChoise.taskId, .equal, taskID)
//                            .all()
//                            .flatMap { choises in
//
//                                Subject.DatabaseModel.query(on: conn)
//                                    .join(\Topic.DatabaseModel.subjectId, to: \Subject.DatabaseModel.id)
//                                    .join(\Subtopic.DatabaseModel.topicId, to: \Topic.DatabaseModel.id)
//                                    .filter(\Subtopic.DatabaseModel.id, .equal, taskContent.0.subtopicID)
//                                    .first()
//                                    .unwrap(or: Abort(.internalServerError))
//                                    .flatMap { subject in
//
//                                        try self.topicRepository
//                                            .getTopicResponses(in: subject.content())
//                                            .map { topics in
//
//                                                try MultipleChoiceTask.ModifyContent(
//                                                    task: Task.ModifyContent(
//                                                        task: taskContent.0,
//                                                        solution: taskContent.2.solution
//                                                    ),
//                                                    subject: subject.content(),
//                                                    topics: topics,
//                                                    multiple: taskContent.1,
//                                                    choises: choises.map { .init(choise: $0) }
//                                                )
//                                        }
//
//                                }
//                        }
//                }
//        }

    }

    public func choisesFor(taskID: MultipleChoiceTask.ID) -> EventLoopFuture<[MultipleChoiseTaskChoise]> {
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
