//
//  FlashCardRepository.swift
//  KognitaCore
//
//  Created by Mats Mollestad on 11/04/2019.
//

import FluentPostgreSQL
import Vapor

public protocol FlashCardTaskRepository: CreateModelRepository,
    UpdateModelRepository,
    DeleteModelRepository
    where
    Model           == FlashCardTask,
    CreateData      == FlashCardTask.Create.Data,
    CreateResponse  == FlashCardTask.Create.Response,
    UpdateData      == FlashCardTask.Edit.Data,
    UpdateResponse  == FlashCardTask.Edit.Response {
    func importTask(from task: Task.BetaFormat, in subtopic: Subtopic) throws -> EventLoopFuture<Void>
    func modifyContent(forID taskID: Task.ID) throws -> EventLoopFuture<FlashCardTask.ModifyContent>
    func createAnswer(for task: FlashCardTask, with submit: FlashCardTask.Submit) -> EventLoopFuture<TaskAnswer>
}

extension FlashCardTask {
    public struct DatabaseRepository: FlashCardTaskRepository, DatabaseConnectableRepository {

        public typealias DatabaseModel = FlashCardTask

        public let conn: DatabaseConnectable
        private var subtopicRepository: some SubtopicRepositoring { Subtopic.DatabaseRepository(conn: conn) }
        private var topicRepository: some TopicRepository { Topic.DatabaseRepository(conn: conn) }
        private var userRepository: some UserRepository { User.DatabaseRepository(conn: conn) }
        private var taskRepository: some TaskRepository { Task.DatabaseRepository(conn: conn) }
    }
}

extension FlashCardTask.DatabaseRepository {

    public func create(from content: FlashCardTask.Create.Data, by user: User?) throws -> EventLoopFuture<Task> {

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

                            try FlashCardTask(task: task)
                                .create(on: self.conn)
                                .transform(to: task)
                    }
                }
        }
    }

    public func update(model flashCard: FlashCardTask, to content: FlashCardTask.Create.Data, by user: User) throws -> EventLoopFuture<Task> {

        guard let task = flashCard.task else {
            throw Abort(.internalServerError)
        }
        try content.validate()

        return try userRepository
            .isModerator(user: user, taskID: flashCard.requireID())
            .flatMap {
                try self.update(task: task, to: content, by: user)
        }
        .catchFlatMap { _ in
            task.get(on: self.conn).flatMap { newTask in
                guard newTask.creatorID == user.id else {
                    throw Abort(.forbidden)
                }
                return try self.update(task: task, to: content, by: user)
            }
        }
    }

    private func update(task: Parent<FlashCardTask, Task>, to content: FlashCardTask.Create.Data, by user: User) throws -> EventLoopFuture<Task> {

        conn.transaction(on: .psql) { conn in
            try FlashCardTask.DatabaseRepository(conn: conn)
                .create(from: content, by: user)
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

    public func delete(model flashCard: FlashCardTask, by user: User?) throws -> EventLoopFuture<Void> {

        guard let user = user else {
            throw Abort(.unauthorized)
        }

        return try userRepository
            .isModerator(user: user, taskID: flashCard.requireID())
            .map { true }
            .catchMap { _ in false }
            .flatMap { isModerator in

                guard let task = flashCard.task else {
                    throw Abort(.internalServerError)
                }
                return task.get(on: self.conn)
                    .flatMap { task in

                        guard isModerator || task.creatorID == user.id else {
                            throw Abort(.forbidden)
                        }
                        return task.delete(on: self.conn)
                }
        }
    }

    public func importTask(from task: Task.BetaFormat, in subtopic: Subtopic) throws -> EventLoopFuture<Void> {

        return try Task(
            subtopicID: subtopic.id,
            description: task.description,
            question: task.question,
            creatorID: 1
        )
            .create(on: conn)
            .flatMap { savedTask in

                try FlashCardTask(
                    taskId: savedTask.requireID()
                )
                    .create(on: self.conn)
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
                                .create(on: self.conn)
                                .transform(to: ())
                        } else {
                            return self.conn.future()
                        }
                }
        }
    }

    public func get(task flashCard: FlashCardTask) throws -> EventLoopFuture<Task> {
        guard let task = flashCard.task else {
            throw Abort(.internalServerError)
        }
        return task.get(on: conn)
    }

    public func getCollection() -> Future<[Task]> {
        return FlashCardTask.query(on: conn)
            .join(\FlashCardTask.id, to: \Task.id)
            .decode(Task.self)
            .all()
    }

    public func content(for flashCard: FlashCardTask) -> EventLoopFuture<TaskPreviewContent> {

        return Task.query(on: conn, withSoftDeleted: true)
            .filter(\Task.id == flashCard.id)
            .join(\Subtopic.DatabaseModel.id, to: \Task.subtopicID)
            .join(\Topic.DatabaseModel.id, to: \Subtopic.DatabaseModel.topicId)
            .join(\Subject.DatabaseModel.id, to: \Topic.DatabaseModel.subjectId)
            .alsoDecode(Topic.DatabaseModel.self)
            .alsoDecode(Subject.DatabaseModel.self)
            .first()
            .unwrap(or: Abort(.internalServerError))
            .map { preview in
                try TaskPreviewContent(
                    subject: preview.1.content(),
                    topic: preview.0.1.content(),
                    task: preview.0.0,
                    actionDescription: FlashCardTask.actionDescriptor
                )
        }
    }

    public func createAnswer(for task: FlashCardTask, with submit: FlashCardTask.Submit) -> EventLoopFuture<TaskAnswer> {
        TaskAnswer()
            .create(on: conn)
            .flatMap { answer in
                try FlashCardAnswer(
                    answerID: answer.requireID(),
                    taskID: task.requireID(),
                    answer: submit.answer
                )
                .create(on: self.conn)
                .transform(to: answer)
        }
    }

    public func modifyContent(forID taskID: Task.ID) throws -> EventLoopFuture<FlashCardTask.ModifyContent> {

        Task.query(on: conn)
            .join(\FlashCardTask.id, to: \Task.id)
            .join(\TaskSolution.taskID, to: \Task.id)
            .filter(\Task.id == taskID)
            .alsoDecode(TaskSolution.self)
            .first()
            .unwrap(or: Abort(.internalServerError))
            .flatMap { taskInfo in

                Subject.DatabaseModel.query(on: self.conn)
                    .join(\Topic.DatabaseModel.subjectId, to: \Subject.DatabaseModel.id)
                    .join(\Subtopic.DatabaseModel.topicId, to: \Topic.DatabaseModel.id)
                    .filter(\Subtopic.DatabaseModel.id == taskInfo.0.subtopicID)
                    .first()
                    .unwrap(or: Abort(.internalServerError))
                    .flatMap { subject in

                        try self.topicRepository.getTopicResponses(in: subject.content())
                            .map { topics in

                                try FlashCardTask.ModifyContent(
                                    task: Task.ModifyContent(
                                        task: taskInfo.0,
                                        solution: taskInfo.1
                                    ),
                                    subject: subject.content(),
                                    topics: topics
                                )
                        }
                }
        }
    }
}
