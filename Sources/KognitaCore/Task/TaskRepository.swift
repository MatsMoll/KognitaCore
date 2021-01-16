//
//  TaskRepository.swift
//  Async
//
//  Created by Mats Mollestad on 12/04/2019.
//

import Vapor
import FluentKit
import FluentSQL

protocol TaskRepository {
    func all() throws -> EventLoopFuture<[TaskDatabaseModel]>
    func create(from content: TaskDatabaseModel.Create.Data, by user: User?) throws -> EventLoopFuture<TaskDatabaseModel>
    func update(taskID: Task.ID, with content: TaskDatabaseModel.Create.Data, by user: User) -> EventLoopFuture<Void>
    func forceDelete(taskID: Task.ID, by user: User) -> EventLoopFuture<Void>
    func getTaskTypePath(for id: Task.ID) throws -> EventLoopFuture<String>
    func taskFor(id: TaskDatabaseModel.IDValue) -> EventLoopFuture<TaskDatabaseModel>
    func getTasks(in subjectId: Subject.ID, user: User, query: TaskOverviewQuery?, maxAmount: Int?, withSoftDeleted: Bool) -> EventLoopFuture<[CreatorTaskContent]>
}

extension TaskDatabaseModel {

    enum Create {
        struct Data {
            let content: TaskCreationContentable
            let subtopicID: Subtopic.ID
            let solution: String
        }
        typealias Response = TaskDatabaseModel

        enum Errors: Error {
            case invalidTopic
        }
    }

    struct DatabaseRepository: TaskRepository, DatabaseConnectableRepository {

        public let database: Database

        internal let repositories: RepositoriesRepresentable
        internal var taskResultRepository: TaskResultRepositoring { repositories.taskResultRepository }
        internal var userRepository: UserRepository { repositories.userRepository }
        internal var resourceRepository: ResourceRepository { repositories.resourceRepository }
        
        private var taskSolutionRepository: TaskSolutionRepositoring { TaskSolution.DatabaseRepository(database: database, userRepository: userRepository) }
    }
}

extension TaskDatabaseModel.DatabaseRepository {

    func all() throws -> EventLoopFuture<[TaskDatabaseModel]> {
        TaskDatabaseModel.query(on: database).all()
    }

    public func create(from content: TaskDatabaseModel.Create.Data, by user: User?) throws -> EventLoopFuture<TaskDatabaseModel> {

        guard content.solution.removeCharacters(from: .whitespaces).isEmpty == false else {
            return database.eventLoop.future(error: Abort(.badRequest))
        }

        guard let user = user else { throw Abort(.unauthorized) }

        let task = try TaskDatabaseModel(
            content: content.content,
            subtopicID: content.subtopicID,
            creator: user
        )
        return task.save(on: database)
            .failableFlatMap {
                try self.taskSolutionRepository.create(
                    from: TaskSolution.Create.Data(
                        solution: content.solution,
                        presentUser: true,
                        taskID: task.requireID()
                ),
                    by: user
                )
                .transform(to: ())
        }
        .failableFlatMap {
            try self.taskResultRepository.createResult(
                from: TaskSubmitResultRepresentableWrapper(
                    taskID: task.requireID(),
                    score: 0.5,
                    timeUsed: nil
                ),
                userID: user.id,
                with: nil
            )
        }
        .flatMapThrowing { _ in try task.requireID() }
        .flatMap { taskID in
            connect(resources: content.content.resources, toTaskID: taskID, userID: user.id)
        }
        .transform(to: task)
    }
    
    func connect(resources: [Resource.Create], toTaskID taskID: Task.ID, userID: User.ID) -> EventLoopFuture<Void> {
        resources.map { (resource: Resource.Create) -> EventLoopFuture<Void> in
            resourceRepository.create(resource: resource, by: userID)
                .flatMap { resourceID -> EventLoopFuture<Void> in
                    resourceRepository.connect(taskID: taskID, to: resourceID)
            }
        }
        .flatten(on: database.eventLoop)
    }

    func update(taskID: Task.ID, with data: TaskDatabaseModel.Create.Data, by user: User) -> EventLoopFuture<Void> {
        taskFor(id: taskID)
            .flatMap { task in
                if user.id == task.$creator.id {
                    return self.database.eventLoop.future(task)
                }
                return self.userRepository
                    .isModerator(user: user, taskID: taskID)
                    .ifFalse(throw: Abort(.forbidden))
                    .transform(to: task)
        }.flatMap { (task: TaskDatabaseModel) -> EventLoopFuture<TaskDatabaseModel> in
            if task.deletedAt != nil {
                return task.restore(on: self.database)
                    .transform(to: task)
            } else {
                return self.database.eventLoop.future(task)
            }
        }
        .failableFlatMap { task in
            try task.update(content: data.content)
                .save(on: self.database)
        }
        .flatMap {
            TaskSolution.DatabaseModel.query(on: self.database)
                .filter(\TaskSolution.DatabaseModel.$task.$id == taskID)
                .all()
        }
        .failableFlatMap { (solutions) -> EventLoopFuture<Void> in
            guard
                solutions.count == 1,
                let solutionID = solutions.first?.id
            else {
                throw Abort(.badRequest)
            }
            return try self.taskSolutionRepository.updateModelWith(
                id: solutionID,
                to: TaskSolution.Update.Data.init(
                    solution: data.solution,
                    presentUser: nil
                ),
                by: user
            )
            .transform(to: ())
        }
    }

    func forceDelete(taskID: Task.ID, by user: User) -> EventLoopFuture<Void> {

        TaskDatabaseModel.query(on: database)
            .withDeleted()
            .filter(\.$id == taskID)
            .first()
            .unwrap(or: Abort(.badRequest))
            .flatMap { task in
                if task.$creator.id == user.id {
                    return task.delete(force: true, on: self.database)
                } else {
                    return self.userRepository.isModerator(user: user, taskID: taskID)
                        .ifFalse(throw: Abort(.unauthorized))
                        .flatMap {
                            task.delete(force: true, on: self.database)
                    }
                }
        }
    }

//    public func getTasks(in subject: Subject) throws -> EventLoopFuture<[TaskContent]> {
//
//        TaskDatabaseModel.query(on: database)
//            .join(parent: \TaskDatabaseModel.$subtopic)
//            .join(parent: \TaskDatabaseModel.$creator)
//            .join(parent: \Subtopic.DatabaseModel.$topic)
//            .filter(Topic.DatabaseModel.self, \Topic.DatabaseModel.$subject.$id == subject.id)
//            .all(with: \.$creator, \.$subtopic, \Subtopic.DatabaseModel.$topic)
//            .flatMapEach(on: database.eventLoop) { (task: TaskDatabaseModel) in
//                failable(eventLoop: self.database.eventLoop) {
//                    try self.taskRepository
//                        .getTaskTypePath(for: task.requireID())
//                        .flatMapThrowing { path in
//                            try TaskContent(
////                                task: task,
//                                topic: task.subtopic.topic.content(),
//                                subject: subject,
//                                creator: task.creator.content(),
//                                taskTypePath: path
//                            )
//                    }
//                }
//        }
//            .flatMap { tasks in
//                try tasks.map { content in
//                    try self.taskRepository.getTaskTypePath(for: content.0.1.requireID()).map { path in
//                        try TaskContent(
//                            task: content.0.1,
//                            topic: content.0.0.content(),
//                            subject: subject,
//                            creator: content.1.content(),
//                            taskTypePath: path
//                        )
//                    }
//                }.flatten(on: self.conn)
//        }
//    }

    func taskFor(id: TaskDatabaseModel.IDValue) -> EventLoopFuture<TaskDatabaseModel> {
        TaskDatabaseModel.query(on: database)
            .withDeleted()
            .filter(\.$id == id)
            .first()
            .unwrap(or: Abort(.badRequest))
    }

    public func getTasks(in topic: Topic) throws -> EventLoopFuture<[TaskDatabaseModel]> {
        return TaskDatabaseModel.query(on: database)
            .join(parent: \TaskDatabaseModel.$subtopic)
            .filter(Subtopic.DatabaseModel.self, \Subtopic.DatabaseModel.$topic.$id == topic.id)
            .all()
    }

//    public func getTasks<A>(where filter: FilterOperator<PostgreSQLDatabase, A>, maxAmount: Int? = nil, withSoftDeleted: Bool = false) throws -> EventLoopFuture<[TaskContent]> {
//
//        return TaskDatabaseModel.query(on: conn, withSoftDeleted: withSoftDeleted)
//            .join(\Subtopic.DatabaseModel.id, to: \TaskDatabaseModel.subtopicID)
//            .join(\Topic.DatabaseModel.id, to: \Subtopic.DatabaseModel.topicID)
//            .join(\Subject.DatabaseModel.id, to: \Topic.DatabaseModel.subjectId)
//            .join(\User.DatabaseModel.id, to: \TaskDatabaseModel.creatorID)
//            .filter(filter)
//            .alsoDecode(Topic.DatabaseModel.self)
//            .alsoDecode(Subject.DatabaseModel.self)
//            .alsoDecode(User.DatabaseModel.self)
//            .range(lower: 0, upper: maxAmount)
//            .all()
//            .flatMap { tasks in
//                try tasks.map { content in
//                    try self.taskRepository
//                        .getTaskTypePath(for: content.0.0.0.requireID())
//                        .map { path in
//                            try TaskContent(
//                                task: content.0.0.0,
//                                topic: content.0.0.1.content(),
//                                subject: content.0.1.content(),
//                                creator: content.1.content(),
//                                taskTypePath: path
//                            )
//                    }
//                }.flatten(on: self.conn)
//        }
//    }

    public func getTasks(in subjectId: Subject.ID, user: User, query: TaskOverviewQuery? = nil, maxAmount: Int? = nil, withSoftDeleted: Bool = false) -> EventLoopFuture<[CreatorTaskContent]> {

        userRepository
            .isModerator(user: user, subjectID: subjectId)
            .flatMap { isModerator in

                var databaseQuery = TaskDatabaseModel.query(on: self.database)
                    .join(parent: \TaskDatabaseModel.$creator)
                    .join(parent: \TaskDatabaseModel.$subtopic)
                    .join(parent: \Subtopic.DatabaseModel.$topic)
                    .join(MultipleChoiceTask.DatabaseModel.self, on: \MultipleChoiceTask.DatabaseModel.$id == \TaskDatabaseModel.$id, method: .left)
                    .filter(Topic.DatabaseModel.self, \Topic.DatabaseModel.$subject.$id == subjectId)
                    .range(lower: 0, upper: maxAmount)

                if let topics = query?.topics, topics.isEmpty == false {
                    databaseQuery = databaseQuery.filter(Topic.DatabaseModel.self, \Topic.DatabaseModel.$id ~~ topics)
                }
                if let question = query?.taskQuestion, question.isEmpty == false {
                    databaseQuery = databaseQuery.filter(\TaskDatabaseModel.$question, .custom("ILIKE"), "%\(question)%")
                }
                if isModerator == false {
                    databaseQuery = databaseQuery.filter(\TaskDatabaseModel.$isTestable == false)
                }

                var noteQuery = databaseQuery.copy()
                    .filter(\TaskDatabaseModel.$deletedAt != nil)
                    .withDeleted()

                if withSoftDeleted == false {
                    noteQuery = noteQuery.filter(\.$creator.$id == user.id)
                }

                return databaseQuery
                    .all(TaskDatabaseModel.self, User.DatabaseModel.self, Topic.DatabaseModel.self, MultipleChoiceTask.DatabaseModel?.self)
                    .flatMap { tasks in
                        noteQuery.all(TaskDatabaseModel.self, User.DatabaseModel.self, Topic.DatabaseModel.self, MultipleChoiceTask.DatabaseModel?.self)
                            .map { notes in tasks + notes }
                    }
                    .flatMapEachThrowing { (task, user, topic, multipleChoice) in
                        try CreatorTaskContent(
                            task: task.content(),
                            topic: topic.content(),
                            creator: user.content(),
                            isMultipleChoise: multipleChoice != nil
                        )
                }
        }
    }

    struct NumberInputTaskKey: Content {
        let correctAnswer: Double?  // NumberInputTask
    }

    struct MultipleChoiseTaskKey: Content {
        let isMultipleSelect: Bool?  // MultipleChoiseTask
    }

    public func getTaskTypePath(for id: Task.ID) throws -> EventLoopFuture<String> {

        // FIXME: Optimize better
        return TaskDatabaseModel.query(on: database)
            .withDeleted()
            .filter(\.$id == id)
            .join(MultipleChoiceTask.DatabaseModel.self, on: \MultipleChoiceTask.DatabaseModel.$id == \TaskDatabaseModel.$id, method: .left)
            .first(TaskDatabaseModel.self, MultipleChoiceTask.DatabaseModel?.self)
            .unwrap(or: Abort(.internalServerError))
            .map { (_, multiple) in
                if multiple != nil {
                    return "tasks/multiple-choise"
                } else {
                    return "tasks/flash-card"
                }
        }
    }

    public func getNumberOfTasks(in subtopicIDs: Subtopic.ID...) -> EventLoopFuture<Int> {
        return TaskDatabaseModel.query(on: database)
            .filter(\.$subtopic.$id ~~ subtopicIDs)
            .count()
    }

    public func getTaskCreators(on database: Database) -> EventLoopFuture<[TaskCreators]> {

        return database.eventLoop.future(error: Abort(.notImplemented))
//        return conn.select()
//            .column(.count(.all, as: "taskCount"))
//            .column(.keyPath(\User.DatabaseModel.id, as: "userID"))
//            .column(.keyPath(\User.DatabaseModel.username, as: "username"))
//            .from(TaskDatabaseModel.self)
//            .join(\TaskDatabaseModel.creatorID, to: \User.DatabaseModel.id)
//            .groupBy(\User.DatabaseModel.id)
//            .all(decoding: TaskCreators.self)
    }

    public func taskType(with id: Task.ID, on database: Database) -> EventLoopFuture<TaskType?> {

        return database.eventLoop.future(error: Abort(.notImplemented))

//        return conn.select()
//            .all(table: TaskDatabaseModel.self)
//            .all(table: MultipleChoiceTask.DatabaseModel.self)
//            .from(TaskDatabaseModel.self)
//            .where(\TaskDatabaseModel.id == id)
//            .join(\TaskDatabaseModel.id, to: \MultipleChoiceTask.DatabaseModel.id, method: .left)
//            .first(decoding: TaskDatabaseModel.self, MultipleChoiceTask.DatabaseModel?.self)
//            .map { task in
//                guard let task = task else { return nil }
//                return TaskType(content: task)
//        }
    }

    public func taskWith(
        id: Int,
        on database: Database
    ) throws -> EventLoopFuture<TaskType> {

        throw Abort(.notImplemented)
//        return conn.select()
//            .all(table: TaskDatabaseModel.self)
//            .all(table: MultipleChoiceTask.DatabaseModel.self)
//            .from(TaskDatabaseModel.self)
//            .join(\TaskDatabaseModel.id, to: \MultipleChoiceTask.DatabaseModel.id, method: .left)
//            .first(decoding: TaskDatabaseModel.self, MultipleChoiceTask.DatabaseModel?.self)
//            .unwrap(or: Abort(.badRequest))
//            .map { taskContent in
//                TaskType(content: taskContent)
//        }
    }

    public func examTasks(subjectID: Subject.ID) -> EventLoopFuture<[TaskDatabaseModel]> {
        return database.eventLoop.future(error: Abort(.notImplemented))
//        TaskDatabaseModel.query(on: conn)
//            .join(\Subtopic.DatabaseModel.id, to: \TaskDatabaseModel.subtopicID)
//            .join(\Topic.DatabaseModel.id, to: \Subtopic.DatabaseModel.topicID)
//            .filter(\.isTestable == true)
//            .filter(\Topic.DatabaseModel.subjectId == subjectID)
//            .all()
    }
}

public struct TaskCreators: Content {

    public let userID: User.ID

    public let username: String

    public let taskCount: Int
}
