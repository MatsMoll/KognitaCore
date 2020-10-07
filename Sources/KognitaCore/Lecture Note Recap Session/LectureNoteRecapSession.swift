//
//  LectureNoteRecapSession.swift
//  KognitaCore
//
//  Created by Mats Mollestad on 28/09/2020.
//

import Fluent
import Vapor
import Foundation
import FluentSQL

// DB - Model

extension LectureNote.RecapSession {
    final class DatabaseModel: Model {

        static var schema: String = "LectureNoteRecapSession"

        @DBID(custom: "id", generatedBy: .user)
        var id: Int?

        @Field(key: "numberOfTasksGoal")
        var numberOfTasksGoal: Int

        @Timestamp(key: "createdAt", on: .create)
        var createdAt: Date?

        @Timestamp(key: "updatedAt", on: .update)
        var updatedAt: Date?

        @Field(key: "endedAt")
        var endedAt: Date?

        @Parent(key: "noteTakingSessionID")
        var noteTakingSession: LectureNote.TakingSession.DatabaseModel

        @Children(for: \.$recapSession)
        var assignedTasks: [LectureNote.RecapSession.AssignedTask]

        init() {}

        init(id: LectureNote.RecapSession.ID, sessionID: LectureNote.TakingSession.ID, numberOfTasksGoal: Int) {
            self.id = id
            self.$noteTakingSession.id = sessionID
            self.numberOfTasksGoal = numberOfTasksGoal
        }
    }

    final class AssignedTask: KognitaPersistenceModel {

        static var tableName: String = "RecapSession_AssignedTask"

        @DBID(custom: "id")
        var id: UUID?

        @Field(key: "index")
        var index: Int

        @Timestamp(key: "createdAt", on: .create)
        var createdAt: Date?

        @Timestamp(key: "updatedAt", on: .update)
        var updatedAt: Date?

        @Field(key: "completedAt")
        var compleatedAt: Date?

        @Parent(key: "taskID")
        var task: TaskDatabaseModel

        @Parent(key: "recapSessionID")
        var recapSession: LectureNote.RecapSession.DatabaseModel

        init() {}

        init(taskID: Task.ID, recapSessionID: LectureNote.RecapSession.ID, index: Int) {
            self.$task.id = taskID
            self.$recapSession.id = recapSessionID
            self.index = index
        }
    }
}

extension LectureNote.RecapSession {
    enum Migrations {}
}

extension LectureNote.RecapSession.Migrations {
    struct Create: KognitaModelMigration {

        var name: String = "LectureNote.RecapSession.Create"

        typealias Model = LectureNote.RecapSession.DatabaseModel

        func build(schema: SchemaBuilder) -> SchemaBuilder {
            schema.field("numberOfTasksGoal", .int, .required)
                .field("endedAt", .datetime)
                .field("noteTakingSessionID", .uuid, .required)
                .foreignKey("noteTakingSessionID", references: LectureNote.TakingSession.DatabaseModel.schema, .id, onDelete: .cascade, onUpdate: .cascade)
                .defaultTimestamps()
        }
    }

    struct CreateAssignedTask: Migration {

        var name: String = "LectureNote.RecapSession.AssignedTask.Create"

        let schema = LectureNote.RecapSession.AssignedTask.schema

        func prepare(on database: Database) -> EventLoopFuture<Void> {
            database.schema(schema)
                .id()
                .field("index", .int, .required)
                .defaultTimestamps()
                .field("completedAt", .datetime)
                .field("taskID", .int, .required, .references(TaskDatabaseModel.schema, .id, onDelete: .cascade, onUpdate: .cascade))
                .field("recapSessionID", .int, .required, .references(LectureNote.RecapSession.DatabaseModel.schema, .id, onDelete: .cascade, onUpdate: .cascade))
                .create()
        }

        func revert(on database: Database) -> EventLoopFuture<Void> {
            database.schema(schema).delete()
        }
    }
}

// Repository

public protocol LectureNoteRecapSessionRepository {
    func create(recap: LectureNote.RecapSession.Create.Data, for user: User) -> EventLoopFuture<LectureNote.RecapSession.ID>
    func currentTaskIndex(sessionID: LectureNote.RecapSession.ID) -> EventLoopFuture<Int>
    func taskWith(index: Int, sessionID: LectureNote.RecapSession.ID) -> EventLoopFuture<GenericTask>
    func submit(answer: LectureNote.RecapSession.Submit, forIndex index: Int, userID: User.ID, sessionID: LectureNote.RecapSession.ID) -> EventLoopFuture<Void>
    func taskContentFor(index: Int, sessionID: LectureNote.RecapSession.ID, userID: User.ID) -> EventLoopFuture<LectureNote.RecapSession.ExecuteTask>
    func taskIDFor(index: Int, sessionID: LectureNote.RecapSession.ID, userID: User.ID) -> EventLoopFuture<Task.ID>
    func getResult(for sessionID: LectureNote.RecapSession.ID) -> EventLoopFuture<[PracticeSession.TaskResult]>
    func subjectFor(sessionID: LectureNote.RecapSession.ID) -> EventLoopFuture<Subject>
}

extension LectureNote.RecapSession {

    struct DatabaseRepository: LectureNoteRecapSessionRepository {

        internal let database: Database
        internal let repositories: RepositoriesRepresentable

        var lectureNoteTakingRepository: LectureNoteTakingSessionRepository { repositories.lectureNoteTakingRepository }

        func create(recap: LectureNote.RecapSession.Create.Data, for user: User) -> EventLoopFuture<LectureNote.RecapSession.ID> {
            lectureNoteTakingRepository.isOwnerOf(sessionID: recap.sessionID, userID: user.id)
                .ifFalse(throw: Abort(.badRequest))
                .flatMap {
                    let session = TaskSession(userID: user.id)
                    return session.create(on: database)
                        .flatMap {
                            LectureNote.RecapSession.DatabaseModel(
                                id: session.id!,
                                sessionID: recap.sessionID,
                                numberOfTasksGoal: recap.numberOfTasks
                            )
                            .save(on: database)
                    }
                    .transform(to: session.id!)
                    .flatMap(assignTaskFor(sessionID: ))
                    .transform(to: session.id!)
                    .flatMap(assignTaskFor(sessionID: ))
                    .transform(to: session.id!)
                }
        }

        private func assignTaskFor(sessionID: LectureNote.RecapSession.ID) -> EventLoopFuture<Int?> {
            LectureNote.RecapSession.DatabaseModel.query(on: database)
                .filter(\LectureNote.RecapSession.DatabaseModel.$id == sessionID)
                .join(parent: \LectureNote.RecapSession.DatabaseModel.$noteTakingSession)
                .first(LectureNote.TakingSession.DatabaseModel.self)
                .unwrap(or: Abort(.badRequest))
                .flatMap { noteTakingSession in

                    LectureNote.RecapSession.AssignedTask.query(on: database)
                        .filter(\.$recapSession.$id == sessionID)
                        .all(\.$task.$id)
                        .flatMap { taskIDs in

                            LectureNote.DatabaseModel.query(on: database)
                                .filter(\.$id !~ taskIDs)
                                .filter(\.$noteSession == noteTakingSession.id!)
                                .all()
                                .failableFlatMap { unfinnishedTasks in

                                    guard let newTask = unfinnishedTasks.randomElement() else {
                                        return database.eventLoop.future(nil)
                                    }
                                    return try LectureNote.RecapSession.AssignedTask(taskID: newTask.requireID(), recapSessionID: sessionID, index: taskIDs.count)
                                        .save(on: database)
                                        .transform(to: taskIDs.count)
                                }
                        }
                }
        }

        public func currentTaskIndex(sessionID: LectureNote.RecapSession.ID) -> EventLoopFuture<Int> {
            LectureNote.RecapSession.AssignedTask.query(on: database)
                .join(parent: \LectureNote.RecapSession.AssignedTask.$recapSession)
                .sort(\.$index, .descending)
                .first()
                .unwrap(or: Abort(.internalServerError))
                .map { $0.index }
        }

        public func taskWith(index: Int, sessionID: LectureNote.RecapSession.ID) -> EventLoopFuture<GenericTask> {
            LectureNote.RecapSession.AssignedTask.query(on: database)
                .withDeleted()
                .filter(\LectureNote.RecapSession.AssignedTask.$index == index)
                .filter(\LectureNote.RecapSession.AssignedTask.$recapSession.$id == sessionID)
                .join(parent: \LectureNote.RecapSession.AssignedTask.$task)
                .first(TaskDatabaseModel.self)
                .unwrap(or: Abort(.badRequest))
                .content()
        }

        public func submit(answer: LectureNote.RecapSession.Submit, forIndex index: Int, userID: User.ID, sessionID: LectureNote.RecapSession.ID) -> EventLoopFuture<Void> {
            LectureNote.RecapSession.DatabaseModel.query(on: database)
                .join(superclass: TaskSession.self, with: LectureNote.RecapSession.DatabaseModel.self)
                .join(children: \LectureNote.RecapSession.DatabaseModel.$assignedTasks)
                .filter(\LectureNote.RecapSession.DatabaseModel.$id == sessionID)
                .filter(TaskSession.self, \.$user.$id == userID)
                .filter(LectureNote.RecapSession.AssignedTask.self, \.$index == index)
                .first(LectureNote.RecapSession.AssignedTask.self)
                .unwrap(or: Abort(.badRequest))
                .map { $0.$task.id }
                .flatMap { taskID in
                    repositories.taskResultRepository.updateResult(
                        with: TaskSubmitResultRepresentableWrapper(
                            taskID: taskID,
                            score: answer.knowledge,
                            timeUsed: answer.timeUsed
                        ),
                        userID: userID,
                        with: sessionID
                    )
                    .flatMap { actionTaken in
                        guard case .created(result: _) = actionTaken else {
                            return database.eventLoop.future()
                        }
                        return repositories.typingTaskRepository
                            .createAnswer(for: taskID, withTextSubmittion: answer.answer)
                            .failableFlatMap { answer in
                                try save(answer: answer, to: sessionID)
                            }
                            .transform(to: sessionID)
                            .flatMap(assignTaskFor(sessionID: ))
                            .transform(to: ())
                    }
                }
        }

        private func save(answer: TaskAnswer, to sessionID: LectureNote.RecapSession.ID) throws -> EventLoopFuture<Void> {
            return try TaskSessionAnswer(
                sessionID: sessionID,
                taskAnswerID: answer.requireID()
            )
            .create(on: database)
        }

        public func taskContentFor(index: Int, sessionID: LectureNote.RecapSession.ID, userID: User.ID) -> EventLoopFuture<LectureNote.RecapSession.ExecuteTask> {

            LectureNote.RecapSession.DatabaseModel.query(on: database)
                .join(superclass: TaskSession.self, with: LectureNote.RecapSession.DatabaseModel.self)
                .filter(\.$id == sessionID)
                .filter(TaskSession.self, \.$user.$id == userID)
                .first()
                .unwrap(or: Abort(.badRequest))
                .flatMap { recapSession in

                    taskWith(index: index, sessionID: sessionID)
                        .flatMap { task in

                            AssignedTask.query(on: database)
                                .filter(\.$recapSession.$id == sessionID)
                                .filter(\.$index == index + 1)
                                .first()
                                .flatMap { nextTask in

                                    repositories.taskResultRepository
                                        .getResult(for: task.id, by: userID, sessionID: sessionID)
                                        .flatMap { result in

                                            repositories.typingTaskRepository
                                                .typingTaskAnswer(in: sessionID, taskID: task.id)
                                                .map { submitedAnswer in

                                                    LectureNote.RecapSession.ExecuteTask(
                                                        task: task,
                                                        numberOfTasksGoal: recapSession.numberOfTasksGoal,
                                                        progress: 0,
                                                        submitedAnswer: submitedAnswer,
                                                        registeredScore: result?.resultScore,
                                                        nextTaskIndex: nextTask?.index,
                                                        prevTaskIndex: index > 0 ? index - 1 : nil
                                                    )
                                                }
                                        }
                                }
                    }
                }
        }

        public func taskIDFor(index: Int, sessionID: LectureNote.RecapSession.ID, userID: User.ID) -> EventLoopFuture<Task.ID> {
            LectureNote.RecapSession.AssignedTask.query(on: database)
                .withDeleted()
                .filter(\LectureNote.RecapSession.AssignedTask.$index == index)
                .filter(\LectureNote.RecapSession.AssignedTask.$recapSession.$id == sessionID)
                .filter(TaskSession.self, \.$user.$id == userID)
                .join(parent: \LectureNote.RecapSession.AssignedTask.$recapSession)
                .join(superclass: TaskSession.self, with: LectureNote.RecapSession.DatabaseModel.self)
                .first()
                .unwrap(or: Abort(.badRequest))
                .map { $0.$task.id }
        }

        public func subjectFor(sessionID: LectureNote.RecapSession.ID) -> EventLoopFuture<Subject> {
            LectureNote.RecapSession.AssignedTask.query(on: database)
                .withDeleted()
                .filter(\LectureNote.RecapSession.AssignedTask.$recapSession.$id == sessionID)
                .join(parent: \LectureNote.RecapSession.AssignedTask.$task)
                .join(parent: \TaskDatabaseModel.$subtopic)
                .join(parent: \Subtopic.DatabaseModel.$topic)
                .join(parent: \Topic.DatabaseModel.$subject)
                .first(Subject.DatabaseModel.self)
                .unwrap(or: Abort(.badRequest))
                .content()
        }

        public func getResult(for sessionID: LectureNote.RecapSession.ID) -> EventLoopFuture<[PracticeSession.TaskResult]> {

            guard let sql = database as? SQLDatabase else {
                return database.eventLoop.future(error: Abort(.internalServerError))
            }
            return sql.select()
                .column(\Topic.DatabaseModel.$name, as: "topicName")
                .column(\Topic.DatabaseModel.$id, as: "topicID")
                .column(\LectureNote.RecapSession.AssignedTask.$index, as: "taskIndex")
                .column(\TaskResult.DatabaseModel.$createdAt, as: "date")
                .column(\TaskResult.DatabaseModel.$resultScore, as: "score")
                .column(\TaskResult.DatabaseModel.$timeUsed, as: "timeUsed")
                .column(\TaskResult.DatabaseModel.$revisitDate, as: "revisitDate")
                .column(\TaskResult.DatabaseModel.$isSetManually, as: "isSetManually")
                .column(\TaskDatabaseModel.$question, as: "question")
                .from(LectureNote.RecapSession.AssignedTask.schema)
                .join(parent: \LectureNote.RecapSession.AssignedTask.$task)
                .join(parent: \TaskDatabaseModel.$subtopic)
                .join(parent: \Subtopic.DatabaseModel.$topic)
                .join(from: \TaskDatabaseModel.$id, to: \TaskResult.DatabaseModel.$task.$id)
                .where(SQLColumn("sessionID", table: TaskResult.DatabaseModel.schema), .equal, SQLBind(sessionID))
                .where(SQLColumn("recapSessionID", table: LectureNote.RecapSession.AssignedTask.schema), .equal, SQLBind(sessionID))
                .all(decoding: PracticeSession.TaskResult.self)
        }
    }
}
