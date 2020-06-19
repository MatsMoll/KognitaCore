//
//  FlashCardRepository.swift
//  KognitaCore
//
//  Created by Mats Mollestad on 11/04/2019.
//

import FluentPostgreSQL
import Vapor

public protocol FlashCardTaskRepository: DeleteModelRepository {
    func create(from content: FlashCardTask.Create.Data, by user: User?) throws -> EventLoopFuture<FlashCardTask.Create.Response>
    func updateModelWith(id: Int, to data: FlashCardTask.Edit.Data, by user: User) throws -> EventLoopFuture<FlashCardTask.Edit.Response>
    func importTask(from task: Task.BetaFormat, in subtopic: Subtopic) throws -> EventLoopFuture<Void>
    func modifyContent(forID taskID: Task.ID) throws -> EventLoopFuture<FlashCardTask.ModifyContent>
    func createAnswer(for task: FlashCardTask, with submit: FlashCardTask.Submit) -> EventLoopFuture<TaskAnswer>
}

extension FlashCardTask {
    public struct DatabaseRepository: FlashCardTaskRepository, DatabaseConnectableRepository {

        init(conn: DatabaseConnectable, repositories: RepositoriesRepresentable) {
            self.conn = conn
            self.repositories = repositories
            self.taskRepository = Task.DatabaseRepository(conn: conn)
        }

        public let conn: DatabaseConnectable
        private let repositories: RepositoriesRepresentable

        private var subtopicRepository: SubtopicRepositoring { repositories.subtopicRepository }
        private var userRepository: UserRepository { repositories.userRepository }
        private let taskRepository: TaskRepository
        private var subjectRepository: SubjectRepositoring { repositories.subjectRepository }
    }
}

extension FlashCardTask.DatabaseRepository {

    public func create(from content: FlashCardTask.Create.Data, by user: User?) throws -> EventLoopFuture<Task> {

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

    public func updateModelWith(id: Int, to data: FlashCardTask.Create.Data, by user: User) throws -> EventLoopFuture<Task> {
        FlashCardTask.find(id, on: conn)
            .unwrap(or: Abort(.badRequest))
            .flatMap { flashCard in

                guard let task = flashCard.task else {
                    throw Abort(.internalServerError)
                }

                return try self.userRepository
                    .isModerator(user: user, taskID: id)
                    .flatMap {
                        try self.update(task: task, to: data, by: user)
                }
                .catchFlatMap { _ in
                    task.get(on: self.conn).flatMap { newTask in
                        guard newTask.creatorID == user.id else {
                            throw Abort(.forbidden)
                        }
                        return try self.update(task: task, to: data, by: user)
                    }
                }
        }
    }

    private func update(task: Parent<FlashCardTask, Task>, to content: FlashCardTask.Create.Data, by user: User) throws -> EventLoopFuture<Task> {

        conn.transaction(on: .psql) { conn in
            try FlashCardTask.DatabaseRepository(conn: conn, repositories: self.repositories)
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

    public func deleteModelWith(id: Int, by user: User?) throws -> EventLoopFuture<Void> {
        FlashCardTask.find(id, on: conn)
            .unwrap(or: Abort(.badRequest))
            .flatMap { task in
                try self.delete(model: task, by: user)
        }
    }

    func delete(model flashCard: FlashCardTask, by user: User?) throws -> EventLoopFuture<Void> {

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

        return Task(
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
                            return try TaskSolution.DatabaseModel(
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
            .join(\Topic.DatabaseModel.id, to: \Subtopic.DatabaseModel.topicID)
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
            .join(\TaskSolution.DatabaseModel.taskID, to: \Task.id)
            .filter(\Task.id == taskID)
            .alsoDecode(TaskSolution.DatabaseModel.self)
            .first()
            .unwrap(or: Abort(.internalServerError))
            .flatMap { taskInfo in

                self.subjectRepository
                    .overviewContaining(subtopicID: taskInfo.0.subtopicID)
                    .map { subject in

                        FlashCardTask.ModifyContent(
                            task: Task.ModifyContent(
                                task: taskInfo.0,
                                solution: taskInfo.1.solution
                            ),
                            subject: subject
                        )
                }
        }
    }
}
