//
//  NumberInputTaskResult.swift
//  App
//
//  Created by Mats Mollestad on 01/04/2019.
//

import Vapor
import FluentKit

public protocol TaskSubmitable {
    var timeUsed: TimeInterval? { get }
}

public protocol TaskSubmitResultable {

    var score: Double { get }
}

/// A Result from a executed task

extension TaskResult {

    final class DatabaseModel: Model {

        static var schema: String = "TaskResult"

        @DBID(custom: "id")
        public var id: Int?

        @Timestamp(key: "createdAt", on: .create)
        public var createdAt: Date?

        /// The date this task should be revisited
        @Field(key: "revisitDate")
        public var revisitDate: Date?

        /// The user how executed the task
        /// Is optional since the user may delete the user, but this info is still relevant for the service
        @OptionalParent(key: "userID")
        public var user: User.DatabaseModel?

        @Parent(key: "taskID")
        public var task: TaskDatabaseModel

        @Field(key: "resultScore")
        public var resultScore: Double

        @Field(key: "timeUsed")
        public var timeUsed: TimeInterval?

        @OptionalParent(key: "sessionID")
        public var session: TaskSession?

        /// If the result value is set manually
        @Field(key: "isSetManually")
        public var isSetManually: Bool

        init() {}

        init(result: TaskSubmitResultRepresentable, userID: User.ID, sessionID: TaskSession.IDValue?) {
            self.$task.id = result.taskID
            self.$user.id = userID
            self.timeUsed = result.timeUsed
            self.resultScore = result.score.clamped(to: 0...1)
            self.$session.id = sessionID
            self.isSetManually = false

            let numberOfDays = ScoreEvaluater.shared.daysUntillReview(score: resultScore)
            let interval = Double(numberOfDays) * 60 * 60 * 24
            self.revisitDate = Date().addingTimeInterval(interval)
        }
    }
}

extension TaskResult: Content { }

extension TaskResult.DatabaseModel: ContentConvertable {
    func content() throws -> TaskResult {
        try .init(
            id: requireID(),
            createdAt: createdAt ?? .now,
            revisitDate: revisitDate,
            userID: $user.id ?? 0,
            taskID: $task.id,
            resultScore: resultScore,
            timeUsed: timeUsed,
            sessionID: $session.id ?? 0
        )
    }
}

extension TaskResult {
    enum Migrations {}
}

extension TaskResult.Migrations {
    struct Create: KognitaModelMigration {

        typealias Model = TaskResult.DatabaseModel

        func build(schema: SchemaBuilder) -> SchemaBuilder {
            schema.field("taskID", .uint, .references(TaskDatabaseModel.schema, .id, onDelete: .cascade, onUpdate: .cascade))
                .field("userID", .uint, .required, .sql(.default(1)), .references(User.DatabaseModel.schema, .id, onDelete: .setDefault, onUpdate: .cascade))
                .field("sessionID", .uint, .references(TaskSession.schema, .id, onDelete: .setNull, onUpdate: .cascade))
                .field("resultScore", .double, .required)
                .field("isSetManually", .bool, .required)
                .field("revisitDate", .datetime)
                .field("timeUsed", .double)
                .field("createdAt", .datetime, .required)
                .unique(on: "sessionID", "taskID")
        }
    }
}

extension TaskResult {
    public var daysUntilRevisit: Int? {
        guard let revisitDate = revisitDate else {
            return nil
        }
        return (Calendar.current.dateComponents([.day], from: Date(), to: revisitDate).day ?? -1) + 1
    }

    public var content: TaskResultContent {
        return TaskResultContent(result: self, daysUntilRevisit: daysUntilRevisit)
    }
}
