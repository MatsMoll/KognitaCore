//
//  FlashCardRepository.swift
//  KognitaCore
//
//  Created by Mats Mollestad on 11/04/2019.
//

import Vapor
import FluentKit

public protocol FlashCardTaskRepository: DeleteModelRepository {
    func create(from content: FlashCardTask.Create.Data, by user: User?) throws -> EventLoopFuture<FlashCardTask.Create.Response>
    func updateModelWith(id: Int, to data: FlashCardTask.Edit.Data, by user: User) throws -> EventLoopFuture<FlashCardTask.Edit.Response>
    func importTask(from task: TaskBetaFormat, in subtopic: Subtopic) throws -> EventLoopFuture<Void>
    func modifyContent(forID taskID: Task.ID) throws -> EventLoopFuture<FlashCardTask.ModifyContent>
    func createAnswer(for task: FlashCardTask, with submit: FlashCardTask.Submit) -> EventLoopFuture<TaskAnswer>
}

extension KognitaContent.TypingTask {
    init(task: TaskDatabaseModel) {
        self.init(
            id: task.id ?? 0,
            subtopicID: task.$subtopic.id,
            description: task.description,
            question: task.question,
            creatorID: task.$creator.id,
            examType: nil,
            examYear: task.examPaperYear,
            isTestable: task.isTestable,
            createdAt: task.createdAt,
            updatedAt: task.updatedAt,
            editedTaskID: nil
        )
    }
}

extension FlashCardTask {
    public struct DatabaseRepository: FlashCardTaskRepository, DatabaseConnectableRepository {

        init(database: Database, repositories: RepositoriesRepresentable) {
            self.database = database
            self.repositories = repositories
            self.taskRepository = TaskDatabaseModel.DatabaseRepository(database: database)
        }

        public let database: Database
        private let repositories: RepositoriesRepresentable

        private var subtopicRepository: SubtopicRepositoring { repositories.subtopicRepository }
        private var userRepository: UserRepository { repositories.userRepository }
        private let taskRepository: TaskRepository
        private var subjectRepository: SubjectRepositoring { repositories.subjectRepository }
    }
}

extension FlashCardTask.DatabaseRepository {

    public func create(from content: FlashCardTask.Create.Data, by user: User?) throws -> EventLoopFuture<TypingTask> {

        guard let user = user else {
            throw Abort(.unauthorized)
        }
//        try content.validate()
        return subtopicRepository
            .find(content.subtopicId)
            .unwrap(or: TaskDatabaseModel.Create.Errors.invalidTopic)
            .flatMap { subtopic in

                failable(eventLoop: self.database.eventLoop) {
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
                        .failableFlatMap { (task: TaskDatabaseModel) in
                            try FlashCardTask(task: task)
                                .create(on: self.database)
                                .map { TypingTask(task: task) }
                    }
                }
        }
    }

    public func updateModelWith(id: Int, to data: FlashCardTask.Create.Data, by user: User) throws -> EventLoopFuture<FlashCardTask.Edit.Response> {
        FlashCardTask.find(id, on: database)
            .unwrap(or: Abort(.badRequest))
            .flatMapThrowing { try $0.requireID() }
            .flatMap(self.taskRepository.taskFor(id: ))
            .failableFlatMap { task in
                if user.id == task.$creator.id {
                    return self.database.eventLoop.future(task)
                }
                return try self.userRepository
                    .isModerator(user: user, taskID: id)
                    .ifFalse(throw: Abort(.forbidden))
                    .transform(to: task)
        }.flatMap { task in
            task.update(content: data)
                .save(on: self.database)
                .map { TypingTask(task: task) }
        }
    }

//    private func update(task: Parent<FlashCardTask, Task>, to content: FlashCardTask.Create.Data, by user: User) throws -> EventLoopFuture<TaskDatabaseModel> {
//
//        conn.transaction(on: .psql) { conn in
//            try FlashCardTask.DatabaseRepository(conn: conn, repositories: self.repositories)
//                .create(from: content, by: user)
//                .flatMap { newTask in
//
//                    task.get(on: conn)
//                        .flatMap { task in
//                            task.deletedAt = Date()  // Equilent to .delete(on: conn)
//                            task.editedTaskID = newTask.id
//                            return task
//                                .save(on: conn)
//                                .transform(to: newTask)
//                    }
//                }
//        }
//    }

    public func deleteModelWith(id: Int, by user: User?) throws -> EventLoopFuture<Void> {
        FlashCardTask.find(id, on: database)
            .unwrap(or: Abort(.badRequest))
            .failableFlatMap { task in
                try self.delete(model: task, by: user)
        }
    }

    func delete(model flashCard: FlashCardTask, by user: User?) throws -> EventLoopFuture<Void> {

        guard let user = user else {
            throw Abort(.unauthorized)
        }

        throw Abort(.notImplemented)
//        return try userRepository
//            .isModerator(user: user, taskID: flashCard.requireID())
//            .map { true }
//            .catchMap { _ in false }
//            .flatMap { isModerator in
//
//                guard let task = flashCard.task else {
//                    throw Abort(.internalServerError)
//                }
//                return task.get(on: self.conn)
//                    .flatMap { task in
//
//                        guard isModerator || task.creatorID == user.id else {
//                            throw Abort(.forbidden)
//                        }
//                        return task.delete(on: self.conn)
//                }
//        }
    }

    public func importTask(from task: TaskBetaFormat, in subtopic: Subtopic) throws -> EventLoopFuture<Void> {

        let savedTask = TaskDatabaseModel(
            subtopicID: subtopic.id,
            description: task.description,
            question: task.question,
            creatorID: 1
        )

        return savedTask.create(on: database)
            .flatMapThrowing {
                try FlashCardTask(taskId: savedTask.requireID())
            }
            .create(on: self.database)
            .failableFlatMap { _ in
                if let solution = task.solution {
                    return try TaskSolution.DatabaseModel(
                        data: TaskSolution.Create.Data(
                            solution: solution,
                            presentUser: true,
                            taskID: savedTask.requireID()
                        ),
                        creatorID: 1
                    )
                    .create(on: self.database)
                } else {
                    return self.database.eventLoop.future()
                }
        }
    }

//    func get(task flashCard: FlashCardTask) throws -> EventLoopFuture<TaskDatabaseModel> {
//        guard let task = flashCard.task else {
//            throw Abort(.internalServerError)
//        }
//        return task.get(on: conn)
//    }

    func getCollection() -> EventLoopFuture<[TaskDatabaseModel]> {
        return FlashCardTask.query(on: database)
            .join(TaskDatabaseModel.self, on: \FlashCardTask.$id == \TaskDatabaseModel.$id)
            .all(TaskDatabaseModel.self)
    }

    public func content(for flashCard: FlashCardTask) -> EventLoopFuture<TaskPreviewContent> {

        database.eventLoop.future(error: Abort(.notImplemented))
//        return TaskDatabaseModel.query(on: db, withSoftDeleted: true)
//            .filter(\TaskDatabaseModel.id == flashCard.id)
//            .join(\Subtopic.DatabaseModel.id, to: \TaskDatabaseModel.subtopicID)
//            .join(\Topic.DatabaseModel.id, to: \Subtopic.DatabaseModel.topicID)
//            .join(\Subject.DatabaseModel.id, to: \Topic.DatabaseModel.subjectId)
//            .alsoDecode(Topic.DatabaseModel.self)
//            .alsoDecode(Subject.DatabaseModel.self)
//            .first()
//            .unwrap(or: Abort(.internalServerError))
//            .map { preview in
//                try TaskPreviewContent(
//                    subject: preview.1.content(),
//                    topic: preview.0.1.content(),
//                    task: preview.0.0,
//                    actionDescription: FlashCardTask.actionDescriptor
//                )
//        }
    }

    public func createAnswer(for task: FlashCardTask, with submit: FlashCardTask.Submit) -> EventLoopFuture<TaskAnswer> {
        let answer = TaskAnswer()

        return answer.create(on: database)
            .flatMapThrowing {
                try FlashCardAnswer(
                    answerID: answer.requireID(),
                    taskID: task.requireID(),
                    answer: submit.answer
                )
        }
        .create(on: database)
        .transform(to: answer)
    }

    public func modifyContent(forID taskID: Task.ID) throws -> EventLoopFuture<FlashCardTask.ModifyContent> {

        throw Abort(.notImplemented)
//        TaskDatabaseModel.query(on: db)
//            .join(\FlashCardTask.id, to: \TaskDatabaseModel.id)
//            .join(\TaskSolution.DatabaseModel.taskID, to: \TaskDatabaseModel.id)
//            .filter(\TaskDatabaseModel.id == taskID)
//            .alsoDecode(TaskSolution.DatabaseModel.self)
//            .first()
//            .unwrap(or: Abort(.internalServerError))
//            .flatMap { taskInfo in
//
//                self.subjectRepository
//                    .overviewContaining(subtopicID: taskInfo.0.subtopicID)
//                    .map { subject in
//
//                        FlashCardTask.ModifyContent(
//                            task: TaskDatabaseModel.ModifyContent(
//                                task: taskInfo.0,
//                                solution: taskInfo.1.solution
//                            ),
//                            subject: subject
//                        )
//                }
//        }
    }
}
