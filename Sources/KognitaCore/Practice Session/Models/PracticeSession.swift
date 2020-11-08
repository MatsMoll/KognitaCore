//
//  PracticeSession.swift
//  App
//
//  Created by Mats Mollestad on 21/01/2019.
//

import FluentSQL
import Vapor

extension Date {
    public var isToday: Bool {
        return Calendar.current.isDateInToday(self)
    }
}

/// A practice session object
extension PracticeSession {
    final class DatabaseModel: KognitaCRUDModel, SoftDeleatableModel {

        public static var tableName: String = "PracticeSession"

        /// The session id
        @DBID(custom: "id", generatedBy: .user)
        public var id: Int?

        /// The date the session was ended
        @Field(key: "endedAt")
        public var endedAt: Date?

        /// The number of task to complete in the session
        @Field(key: "numberOfTaskGoal")
        public var numberOfTaskGoal: Int

        /// The date when the session was started
        @Timestamp(key: "createdAt", on: .create)
        public var createdAt: Date?

        @Timestamp(key: "updatedAt", on: .update)
        public var updatedAt: Date?

        @Timestamp(key: "deletedAt", on: .delete)
        public var deletedAt: Date?

        @Field(key: "useTypingTasks")
        var useTypingTasks: Bool

        @Field(key: "useMultipleChoiceTasks")
        var useMultipleChoiceTasks: Bool

        var useAllTaskTypes: Bool { useTypingTasks && useMultipleChoiceTasks }

        @Siblings(through: PracticeSession.Pivot.Subtopic.self, from: \.$session, to: \.$subtopic)
        var subtopics: [Subtopic.DatabaseModel]

        @Siblings(through: PracticeSession.Pivot.Task.self, from: \.$session, to: \.$task)
        var tasks: [TaskDatabaseModel]

        init() {}

        init(sessionID: TaskSession.IDValue, numberOfTaskGoal: Int, useTypingTasks: Bool, useMultipleChoiceTasks: Bool, addTasksLazely: Bool) throws {
            self.id = sessionID
            guard numberOfTaskGoal > 0 else {
                throw Abort(.badRequest, reason: "Needs more then 0 task goal")
            }
            self.numberOfTaskGoal = numberOfTaskGoal
            self.useTypingTasks = useTypingTasks
            self.useMultipleChoiceTasks = useMultipleChoiceTasks
            self.endedAt = nil
            self.deletedAt = nil
        }
    }
}

extension PracticeSession {
    func representable(on database: Database) -> EventLoopFuture<PracticeSessionRepresentable> {
        PracticeSession.PracticeParameter.resolveWith(id, database: database)
    }
}

extension PracticeSession {
    enum Migrations {
        struct Create: KognitaModelMigration {
            typealias Model = PracticeSession.DatabaseModel

            func build(schema: SchemaBuilder) -> SchemaBuilder {
                schema.field("endedAt", .date)
                    .field("numberOfTaskGoal", .int, .required)
                    .field("deletedAt", .datetime)
                    .foreignKey("id", references: TaskSession.schema, .id, onDelete: .cascade, onUpdate: .cascade)
                    .field("useTypingTasks", .bool, .sql(.default(true)))
                    .field("useMultipleChoiceTasks", .bool, .sql(.default(true)))
                    .defaultTimestamps()
            }
        }

        struct SelectiveTaskType: Migration {

            func prepare(on database: Database) -> EventLoopFuture<Void> {
                database.schema(PracticeSession.DatabaseModel.schema)
                    .field("useTypingTasks", .bool, .sql(.default(true)))
                    .field("useMultipleChoiceTasks", .bool, .sql(.default(true)))
                    .update()
            }

            func revert(on database: Database) -> EventLoopFuture<Void> {
                database.schema(PracticeSession.DatabaseModel.schema)
                    .deleteField("useTypingTasks")
                    .deleteField("useMultipleChoiceTasks")
                    .update()
            }
        }
    }
}

extension PracticeSession.DatabaseModel {

    func representable(with session: TaskSession) -> PracticeSessionRepresentable {
        PracticeSession.PracticeParameter(session: session, practiceSession: self)
    }

    func representable(on database: Database) throws -> EventLoopFuture<PracticeSessionRepresentable> {
        let session = self
        return try TaskSession.find(requireID(), on: database)
            .unwrap(or: Abort(.internalServerError))
            .map { PracticeSession.PracticeParameter(session: $0, practiceSession: session) }
    }

    func numberOfCompletedTasks(with database: Database) throws -> EventLoopFuture<Int> {
        throw Abort(.notImplemented)
//        return try self.$tasks
//            .query(on: db)
//            .filter(\.$isCompleted == true)
//            .count()
    }

//    public func getCurrentTaskIndex(_ conn: DatabaseConnectable) throws -> EventLoopFuture<Int> {
//        return try DatabaseRepository
//            .getCurrentTaskIndex(for: self.requireID(), on: conn)
//    }
//
//    public func currentTask(on conn: PostgreSQLConnection) throws -> EventLoopFuture<TaskType> {
//        return try DatabaseRepository
//            .currentActiveTask(in: self, on: conn)
//    }
//
//    public func taskAt(index: Int, on conn: PostgreSQLConnection) throws -> EventLoopFuture<TaskType> {
//        return try DatabaseRepository
//            .taskAt(index: index, in: requireID(), on: conn)
//    }

    public func pathFor(index: Int) throws -> String {
        return try "/practice-sessions/\(requireID())/tasks/\(index)"
    }
}

extension PracticeSession.DatabaseModel {

    public var timeUsed: TimeInterval? {
        guard let createdAt = createdAt,
            let endedAt = endedAt else {
             return nil
        }
        return endedAt.timeIntervalSince(createdAt)
    }
}

extension PracticeSession: Content {}

extension TaskType {
    init(content: (task: TaskDatabaseModel, chocie: MultipleChoiceTask.DatabaseModel?, exam: Exam.DatabaseModel?)) {
        self.init(
            task: GenericTask(task: content.task, exam: try? content.exam?.content()),
            isMultipleSelect: content.chocie?.isMultipleSelect
        )
    }
}
