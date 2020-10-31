//
//  MultipleChoiseTaskRepository.swift
//  KognitaCore
//
//  Created by Mats Mollestad on 11/04/2019.
//

import FluentSQL
import Vapor

extension MultipleChoiceTaskChoice.Answered: Content {}
extension MultipleChoiceTaskChoice.Result: Content {}

public protocol MultipleChoiseTaskRepository: DeleteModelRepository {
    func create(from content: MultipleChoiceTask.Create.Data, by user: User?) throws -> EventLoopFuture<MultipleChoiceTask.Create.Response>
    func updateModelWith(id: Int, to data: MultipleChoiceTask.Update.Data, by user: User) throws -> EventLoopFuture<MultipleChoiceTask.Update.Response>
    func task(withID taskID: Task.ID) throws -> EventLoopFuture<MultipleChoiceTask>
    func modifyContent(forID taskID: Task.ID) throws -> EventLoopFuture<MultipleChoiceTask.ModifyContent>
    func create(answer submit: MultipleChoiceTask.Submit, sessionID: TestSession.ID) -> EventLoopFuture<[TaskAnswer]>
    func evaluate(_ choises: [MultipleChoiceTaskChoice.ID], for taskID: MultipleChoiceTask.ID) throws -> EventLoopFuture<TaskSessionResult<[MultipleChoiceTaskChoice.Result]>>
    func importTask(from taskContent: MultipleChoiceTask.BetaFormat, in subtopic: Subtopic) throws -> EventLoopFuture<Void>
    func createAnswer(choiseID: MultipleChoiceTaskChoice.ID, sessionID: TestSession.ID) -> EventLoopFuture<TaskAnswer>
    func choisesFor(taskID: MultipleChoiceTask.ID) -> EventLoopFuture<[MultipleChoiceTaskChoice]>
    func correctChoisesFor(taskID: Task.ID) -> EventLoopFuture<[MultipleChoiceTaskChoice]>
    func evaluate(_ choises: [MultipleChoiceTaskChoice.ID], agenst correctChoises: [MultipleChoiceTaskChoice]) throws -> TaskSessionResult<[MultipleChoiceTaskChoice.Result]>
    func multipleChoiseAnswers(in sessionID: Sessions.ID, taskID: Task.ID) -> EventLoopFuture<[MultipleChoiceTaskChoice.Answered]>
    func forceDelete(taskID: Task.ID, by user: User) -> EventLoopFuture<Void>
}

extension MultipleChoiceTask {
    public struct DatabaseRepository: MultipleChoiseTaskRepository, DatabaseConnectableRepository {

        init(database: Database, repositories: RepositoriesRepresentable) {
            self.database = database
            self.repositories = repositories
            self.taskRepository = TaskDatabaseModel.DatabaseRepository(database: database, taskResultRepository: repositories.taskResultRepository, userRepository: repositories.userRepository)
        }

        public let database: Database
        private let repositories: RepositoriesRepresentable
        private let taskRepository: TaskRepository

        private var subtopicRepository: SubtopicRepositoring { repositories.subtopicRepository }
        private var userRepository: UserRepository { repositories.userRepository }
        private var subjectRepository: SubjectRepositoring { repositories.subjectRepository }
        private var topicRepository: TopicRepository { repositories.topicRepository }
        private var taskAnswerRepository: TaskSessionAnswerRepository { TaskSessionAnswer.DatabaseRepository(database: database) }
    }
}

extension MultipleChoiceTask.Create.Data: Validatable {

//    public static func validations() throws -> Validations<MultipleChoiceTask.Create.Data> {
//        var validations = try basicValidations()
//        validations.add(\.self, at: ["choices"], "Contains choices") { data in
//            guard data.isMultipleSelect == false else { return }
//            guard data.choises.filter({ $0.isCorrect }).count == 1 else {
//                throw BasicValidationError("Need to set a correct answer")
//            }
//        }
//        validations.add(\.choises, at: ["choices"], "Unique choices") { (choices) in
//            guard Set(choices.map { $0.choice }).count == choices.count else {
//                throw BasicValidationError("Some choices contain the same description")
//            }
//        }
//        return validations
//    }
}

extension MultipleChoiceTask.DatabaseRepository {

    public func multipleChoiseAnswers(in sessionID: Sessions.ID, taskID: Task.ID) -> EventLoopFuture<[MultipleChoiceTaskChoice.Answered]> {
        choisesFor(taskID: taskID)
            .flatMap { choices in
                self.taskAnswerRepository.multipleChoiseAnswers(in: sessionID, taskID: taskID, choices: choices)
        }
    }

    public func task(withID taskID: Task.ID) throws -> EventLoopFuture<MultipleChoiceTask> {
        MultipleChoiceTask.DatabaseModel.query(on: database)
            .with(\.$choices)
            .filter(\.$id == taskID)
            .first()
            .unwrap(or: Abort(.badRequest))
            .flatMap { multipleChoice in

                TaskDatabaseModel.find(taskID, on: self.database)
                    .unwrap(or: Abort(.badRequest))
                    .flatMapThrowing { task in
                        try multipleChoice.content(task: task, choices: multipleChoice.choices)
                }
        }
    }

    public func create(from content: MultipleChoiceTask.Create.Data, by user: User?) throws -> EventLoopFuture<MultipleChoiceTask> {
//        try content.validate()
        guard let user = user else {
            throw Abort(.unauthorized)
        }
        guard content.choises.isEmpty == false else {
            throw Abort(.badRequest)
        }
        return self.subtopicRepository
            .find(content.subtopicId, or: TaskDatabaseModel.Create.Errors.invalidTopic)
            .failableFlatMap { subtopic in
                try self.taskRepository
                    .create(
                        from: TaskDatabaseModel.Create.Data(
                            content: content,
                            subtopicID: subtopic.id,
                            solution: content.solution
                        ),
                        by: user
                )
        }
        .failableFlatMap { task in
            let multipleChoice = try MultipleChoiceTask.DatabaseModel(
                isMultipleSelect: content.isMultipleSelect,
                task: task
            )
            return multipleChoice
                .create(on: self.database)
                .map {
                    content.choises.compactMap {
                        try? MultipleChoiseTaskChoise(choise: $0.choice, isCorrect: $0.isCorrect, taskId: task.requireID())
                    }
            }.flatMap { choices in
                choices.map { $0.save(on: self.database) }
                    .flatten(on: self.database.eventLoop)
                    .flatMapThrowing {
                        try multipleChoice.content(task: task, choices: choices)
                }
            }
        }
    }

    public func updateModelWith(id: Int, to data: MultipleChoiceTask.Update.Data, by user: User) throws -> EventLoopFuture<MultipleChoiceTask> {
        guard data.choises.contains(where: { $0.isCorrect }) else { throw Abort(.badRequest) }
        return taskRepository.taskFor(id: id)
            .failableFlatMap { task in
                guard task.$creator.id == user.id else {
                    return self.userRepository.isModerator(user: user, taskID: id)
                }
                return self.database.eventLoop.future(true)
        }
        .ifFalse(throw: Abort(.forbidden))
        .failableFlatMap {
            try self.create(from: data, by: user)
        }
        .failableFlatMap { task in
            try TaskDatabaseModel(content: data, subtopicID: data.subtopicId, creator: user, id: id)
                .delete(on: self.database)
                .transform(to: task)
        }
    }

    public func deleteModelWith(id: Int, by user: User?) throws -> EventLoopFuture<Void> {

        guard let user = user else {
            throw Abort(.unauthorized)
        }

        return userRepository
            .isModerator(user: user, taskID: id)
            .flatMap { isModerator in

                TaskDatabaseModel.find(id, on: self.database)
                    .unwrap(or: Abort(.badRequest))
                    .flatMap { task in
                        guard isModerator || task.$creator.id == user.id else {
                            return self.database.eventLoop.future(error: Abort(.forbidden))
                        }
                        return task
                            .delete(on: self.database)
                            .transform(to: ())
                }
        }
    }

    public func importTask(from taskContent: MultipleChoiceTask.BetaFormat, in subtopic: Subtopic) throws -> EventLoopFuture<Void> {

        let savedTask = TaskDatabaseModel(
            subtopicID: subtopic.id,
            description: taskContent.task.description,
            question: taskContent.task.question,
            creatorID: 1
        )

        return savedTask.create(on: database)
            .failableFlatMap {

                if let solution = taskContent.task.solution {
                    return try TaskSolution.DatabaseModel(
                        data: TaskSolution.Create.Data(
                            solution: solution,
                            presentUser: true,
                            taskID: savedTask.requireID()),
                        creatorID: 1
                    )
                        .create(on: self.database)
                        .failableFlatMap {
                            try MultipleChoiceTask.DatabaseModel(
                                isMultipleSelect: taskContent.isMultipleSelect,
                                taskID: savedTask.requireID()
                            )
                            .create(on: self.database)
                    }
                } else {
                    return try MultipleChoiceTask.DatabaseModel(
                        isMultipleSelect: taskContent.isMultipleSelect,
                        taskID: savedTask.requireID()
                    )
                        .create(on: self.database)
                }
        }.failableFlatMap {
            try taskContent.choises
                .map { choise in
                    try MultipleChoiseTaskChoise(
                        choise: choise.choice,
                        isCorrect: choise.isCorrect,
                        taskId: savedTask.requireID()
                    )
                    .create(on: self.database)
            }
            .flatten(on: self.database.eventLoop)
        }
    }

    public func get(task: MultipleChoiceTask) throws -> EventLoopFuture<MultipleChoiceTask> {

        throw Abort(.notImplemented)
//        MultipleChoiceTask.DatabaseModel.query(on: conn)
//            .join(\MultipleChoiseTaskChoise.taskId, to: \MultipleChoiceTask.DatabaseModel.id)
//            .join(\TaskDatabaseModel.id, to: \MultipleChoiseTaskChoise.taskId)
//            .filter(\MultipleChoiceTask.DatabaseModel.id == task.id)
//            .alsoDecode(TaskDatabaseModel.self)
//            .alsoDecode(MultipleChoiseTaskChoise.self)
//            .all()
//            .map { choises in
//                guard let first = choises.first else {
//                    throw Abort(.noContent, reason: "Missing choises in task")
//                }
//                return MultipleChoiceTask(
//                    task: first.0.1,
//                    isMultipleSelect: first.0.0.isMultipleSelect,
//                    choises: choises.map { $0.1 }.shuffled()
//                )
//        }
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
    public func evaluate(_ choises: [MultipleChoiceTaskChoice.ID], for taskID: MultipleChoiceTask.ID) throws -> EventLoopFuture<TaskSessionResult<[MultipleChoiceTaskChoice.Result]>> {

        return MultipleChoiseTaskChoise.query(on: database)
            .filter(\MultipleChoiseTaskChoise.$task.$id == taskID)
            .filter(\MultipleChoiseTaskChoise.$isCorrect == true)
            .all()
            .flatMapEachThrowing { try MultipleChoiceTaskChoice(choice: $0) }
            .flatMapThrowing { correctChoises in
                try self.evaluate(choises, agenst: correctChoises)
        }
    }

    /// Evaluates the submited data and returns a score indicating *how much correct* the answer was
    public func evaluate(_ choises: [MultipleChoiceTaskChoice.ID], agenst correctChoises: [MultipleChoiceTaskChoice]) throws -> TaskSessionResult<[MultipleChoiceTaskChoice.Result]> {

        var numberOfCorrect = 0
        var numberOfIncorrect = 0
        var missingAnswers = correctChoises.filter({ $0.isCorrect })
        var results = [MultipleChoiceTaskChoice.Result]()

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
        results += missingAnswers.map {
            .init(id: $0.id, isCorrect: true)
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
        .flatten(on: database.eventLoop)
    }

    public func createAnswer(choiseID: MultipleChoiceTaskChoice.ID, sessionID: TestSession.ID) -> EventLoopFuture<TaskAnswer> {
        let answer = TaskAnswer()

        return answer.save(on: database)
            .flatMapThrowing {
                try MultipleChoiseTaskAnswer(answerID: answer.requireID(), choiseID: choiseID)
            }
            .create(on: database)
            .flatMapThrowing {
                try TaskSessionAnswer(sessionID: sessionID, taskAnswerID: answer.requireID())
            }
            .create(on: database)
            .transform(to: answer)
    }

    public func correctChoisesFor(taskID: Task.ID) -> EventLoopFuture<[MultipleChoiceTaskChoice]> {
        MultipleChoiseTaskChoise.query(on: database)
            .filter(\MultipleChoiseTaskChoise.$task.$id == taskID)
            .filter(\.$isCorrect == true)
            .all()
            .flatMapEachThrowing { try MultipleChoiceTaskChoice(choice: $0) }
    }

    public func modifyContent(forID taskID: Task.ID) throws -> EventLoopFuture<MultipleChoiceTask.ModifyContent> {

        TaskDatabaseModel.query(on: database)
            .withDeleted()
            .join(superclass: MultipleChoiceTask.DatabaseModel.self, with: TaskDatabaseModel.self)
            .filter(\.$id == taskID)
            .first(TaskDatabaseModel.self, MultipleChoiceTask.DatabaseModel.self)
            .unwrap(or: Abort(.internalServerError))
            .flatMap { (task, multipleChoice) in

                TaskSolution.DatabaseModel.query(on: self.database)
                    .filter(\.$task.$id == taskID)
                    .all()
                    .flatMap { solutions in

                        self.subjectRepository
                            .overviewContaining(subtopicID: task.$subtopic.id)
                            .flatMap { subjectOverview in

                                self.topicRepository
                                    .topicsWithSubtopics(subjectID: subjectOverview.id)
                                    .flatMap { topics in

                                        self.choisesFor(taskID: taskID)
                                            .flatMapThrowing { choices in

                                                try MultipleChoiceTask.ModifyContent(
                                                    task: TaskModifyContent(
                                                        task: task.content(),
                                                        solutions: solutions.compactMap { try? $0.content() }
                                                    ),
                                                    subject: Subject(
                                                        id: subjectOverview.id,
                                                        name: subjectOverview.name,
                                                        description: subjectOverview.description,
                                                        category: subjectOverview.category
                                                    ),
                                                    isMultipleSelect: multipleChoice.isMultipleSelect,
                                                    choises: choices,
                                                    topics: topics
                                                )
                                        }
                                }
                        }
                }
        }
    }

    public func choisesFor(taskID: MultipleChoiceTask.ID) -> EventLoopFuture<[MultipleChoiceTaskChoice]> {
        MultipleChoiseTaskChoise.query(on: database)
            .withDeleted()
            .filter(\MultipleChoiseTaskChoise.$task.$id == taskID)
            .all()
            .flatMapEachThrowing { try MultipleChoiceTaskChoice(choice: $0) }
    }

    public func forceDelete(taskID: Task.ID, by user: User) -> EventLoopFuture<Void> {
        taskRepository.forceDelete(taskID: taskID, by: user)
    }
}
