//
//  TypingTask+DatabaseRepository.swift
//  KognitaCore
//
//  Created by Mats Mollestad on 14/11/2020.
//

import Vapor
import FluentKit
import FluentSQL

extension TypingTask {
    /// A database implementation of a `TypingTaskRepository`
    public struct DatabaseRepository: TypingTaskRepository, DatabaseConnectableRepository {

        init(database: Database, repositories: RepositoriesRepresentable) {
            self.database = database
            self.repositories = repositories
            self.taskRepository = TaskDatabaseModel.DatabaseRepository(database: database, repositories: repositories)
        }

        /// The database the repo is connected to
        public let database: Database

        /// The other repositories needed
        private let repositories: RepositoriesRepresentable

        /// The task repository to use
        private let taskRepository: TaskRepository

        private var subtopicRepository: SubtopicRepositoring { repositories.subtopicRepository }
        private var userRepository: UserRepository { repositories.userRepository }
        private var subjectRepository: SubjectRepositoring { repositories.subjectRepository }
        private var resourceRepository: ResourceRepository { repositories.resourceRepository }
        private var taskAnswerRepository: TaskSessionAnswerRepository { TaskSessionAnswer.DatabaseRepository(database: database) }
    }
}

extension TypingTask.DatabaseRepository {

    public func typingTaskAnswer(in sessionID: Sessions.ID, taskID: Task.ID) -> EventLoopFuture<TypingTask.Answer?> {
        self.taskAnswerRepository.typingTaskAnswer(in: sessionID, taskID: taskID)
    }

    public func create(from content: TypingTask.Create.Data, by user: User?) throws -> EventLoopFuture<TypingTask> {

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

    public func updateModelWith(id: Int, to data: TypingTask.Create.Data, by user: User) throws -> EventLoopFuture<TypingTask.Update.Response> {
        FlashCardTask.find(id, on: database)
            .unwrap(or: Abort(.badRequest))
            .flatMap { taskID in
                self.taskRepository.update(
                    taskID: id,
                    with: TaskDatabaseModel.Create.Data(
                        content: data,
                        subtopicID: data.subtopicId,
                        solution: data.solution
                    ),
                    by: user
                )
        }
        .flatMap { self.taskRepository.taskFor(id: id) }
        .map { TypingTask(task: $0) }
    }

    public func deleteModelWith(id: Int, by user: User?) throws -> EventLoopFuture<Void> {
        FlashCardTask.find(id, on: database)
            .unwrap(or: Abort(.badRequest))
            .failableFlatMap { task in
                try self.delete(model: task, by: user)
        }
    }

    func delete(model flashCard: FlashCardTask, by user: User?) throws -> EventLoopFuture<Void> {

        guard let user = user else { throw Abort(.unauthorized) }
        let id = try flashCard.requireID()

        return try userRepository
            .isModerator(user: user, taskID: flashCard.requireID())
            .flatMap { isModerator in

                self.taskRepository.taskFor(id: id)
                    .failableFlatMap { task in

                        guard isModerator || task.$creator.id == user.id else {
                            throw Abort(.forbidden)
                        }
                        return task.delete(on: self.database)
                }
        }
    }

    public func importTask(from task: TypingTask.Import, in subtopic: Subtopic, examID: Exam.ID?, resourceMap: [Resource.ID: Resource.ID]) -> EventLoopFuture<Void> {

        let savedTask = TaskDatabaseModel(
            subtopicID: subtopic.id,
            description: task.description,
            question: task.question,
            creatorID: 1,
            examID: examID
        )

        guard task.solutions.isEmpty == false else {
            return database.eventLoop.future(error: Abort(.badRequest, reason: "Missing solutions for typing task"))
        }

        return savedTask.create(on: database)
            .flatMapThrowing {
                try FlashCardTask(taskId: savedTask.requireID())
            }
            .create(on: self.database)
            .failableFlatMap { () -> EventLoopFuture<Task.ID> in
                let taskID = try savedTask.requireID()
                return try task.solutions.map { solution in
                    try TaskSolution.DatabaseModel(
                        data: TaskSolution.Create.Data(
                            solution: solution.solution,
                            presentUser: true,
                            taskID: taskID
                        ),
                        creatorID: 1
                    )
                    .create(on: database)
                }
                .flatten(on: database.eventLoop)
                .transform(to: taskID)
            }
            .flatMap { taskID in
                guard let sources = task.sources else { return database.eventLoop.future() }
                return sources.compactMap { oldResourceID in
                    resourceMap[oldResourceID]
                }.map { resourceID in
                    resourceRepository.connect(taskID: taskID, to: resourceID)
                }
                .flatten(on: database.eventLoop)
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

    public func content(for flashCard: TypingTask) -> EventLoopFuture<TaskPreviewContent> {

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

    public func createAnswer(for taskID: TypingTask.ID, withTextSubmittion submit: String) -> EventLoopFuture<TaskAnswer> {

        let answer = TaskAnswer()

        return answer.create(on: database)
            .flatMapThrowing {
                try FlashCardAnswer(
                    answerID: answer.requireID(),
                    taskID: taskID,
                    answer: submit
                )
        }
        .create(on: database)
        .transform(to: answer)
    }

    public func modifyContent(forID taskID: Task.ID) -> EventLoopFuture<TypingTask.ModifyContent> {

        TaskDatabaseModel.query(on: database)
            .withDeleted()
            .join(superclass: FlashCardTask.self, with: TaskDatabaseModel.self)
            .filter(\.$id == taskID)
            .first(TaskDatabaseModel.self)
            .unwrap(or: Abort(.internalServerError))
            .flatMap { (task) in

                TaskSolution.DatabaseModel.query(on: database)
                    .filter(\.$task.$id == taskID)
                    .all()
                    .flatMap { solutions in

                        subjectRepository
                            .overviewContaining(subtopicID: task.$subtopic.id)
                            .flatMap { subjectOverview in

                                repositories.examRepository
                                    .allExamsWith(subjectID: subjectOverview.id)
                                    .flatMap { exams in

                                        repositories.topicRepository
                                            .topicsWithSubtopics(subjectID: subjectOverview.id)
                                            .flatMapThrowing { topics in

                                                try TypingTask.ModifyContent(
                                                    subject: Subject(
                                                        id: subjectOverview.id,
                                                        code: subjectOverview.code,
                                                        name: subjectOverview.name,
                                                        description: subjectOverview.description,
                                                        category: subjectOverview.category
                                                    ),
                                                    topics: topics,
                                                    exams: exams,
                                                    task: TaskModifyContent(
                                                        task: task.content(),
                                                        solutions: solutions.compactMap { try? $0.content() }
                                                    )
                                                )
                                        }
                                    }
                        }
                }
        }
    }

    public func forceDelete(taskID: Task.ID, by user: User) -> EventLoopFuture<Void> {
        taskRepository.forceDelete(taskID: taskID, by: user)
    }

    public func allTaskAnswers(for subjectID: Subject.ID) -> EventLoopFuture<[TypingTask.AnswerResult]> {

        guard let sql = database as? SQLDatabase else {
            return database.eventLoop.future(error: Abort(.internalServerError, reason: "Unable to connect to SQL database"))
        }

        return sql.select()
            .column(\Topic.DatabaseModel.$subject.$id, as: "subjectID")
            .column(\TaskResult.DatabaseModel.$resultScore, as: "score")
            .column(\TaskResult.DatabaseModel.$isSetManually, as: "isSetManually")
            .column(\FlashCardAnswer.$answer, as: "answer")
            .column(\FlashCardAnswer.$task.$id, as: "taskID")
            .from(TaskSessionAnswer.schema)
            .join(from: \TaskSessionAnswer.$taskAnswer.$id, to: \FlashCardAnswer.$id)
            .join(from: \FlashCardAnswer.$task.$id, to: \TaskDatabaseModel.$id)
            .join(from: \TaskDatabaseModel.$subtopic.$id, to: \Subtopic.DatabaseModel.$id)
            .join(from: \Subtopic.DatabaseModel.$topic.$id, to: \Topic.DatabaseModel.$id)
            .join(TaskResult.DatabaseModel.schema, on: #"("\#(TaskResult.DatabaseModel.schema)"."sessionID"="\#(TaskSessionAnswer.schema)"."sessionID" AND "\#(TaskResult.DatabaseModel.schema)"."taskID"="\#(TaskDatabaseModel.schema)"."id")"#)
            .where("subjectID", .equal, subjectID)
            .all(decoding: TypingTask.AnswerResult.self)

//        TaskSessionAnswer.query(on: database)
//            .join(parent: \TaskSessionAnswer.$taskAnswer)
//            .join(superclass: FlashCardAnswer.self, with: TaskAnswer.self)
//            .join(parent: \FlashCardAnswer.$task)
//            .join(parent: \TaskDatabaseModel.$subtopic)
//            .join(parent: \Subtopic.DatabaseModel.$topic)
//            .filter(Topic.DatabaseModel.self, \Topic.DatabaseModel.$subject.$id == subjectID)
    }

//    public func createDraft(from content: TypingTask.Create.Draft, by user: User) throws -> EventLoopFuture<TypingTask.ID> {
//
//        try self.taskRepository
//            .create(
//                from: TaskDatabaseModel.Create.Data(
//                    content: content,
//                    subtopicID: content.subtopicID,
//                    solution: content.solution ?? ""
//                ),
//                by: user
//        ).failableFlatMap { task in
//            try FlashCardTask(task: task)
//                .create(on: self.database)
//                .flatMap {
//                    // Sets deletedAt in order to not use them while a draft
//                    task.delete(on: self.database)
//                }
//                .flatMapThrowing { try task.requireID() }
//        }
//
//    }
}
