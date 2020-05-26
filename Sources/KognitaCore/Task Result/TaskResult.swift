//
//  NumberInputTaskResult.swift
//  App
//
//  Created by Mats Mollestad on 01/04/2019.
//

import Vapor
import FluentPostgreSQL

public protocol TaskSubmitable {
    var timeUsed: TimeInterval? { get }
}

public protocol TaskSubmitResultable {

    var score: Double { get }
}

/// A Result from a executed task
public final class TaskResult: PostgreSQLModel, Codable {

    public typealias Database = PostgreSQLDatabase

    public static var createdAtKey: TimestampKey? = \.createdAt

    public var id: Int?

    public var createdAt: Date?

    /// The date this task should be revisited
    public var revisitDate: Date?

    /// The user how executed the task
    /// Is optional since the user may delete the user, but this info is still relevant for the service
    public var userID: User.ID?

    public var taskID: Task.ID

    public var resultScore: Double

    public var timeUsed: TimeInterval?

    public var sessionID: TaskSession.ID?

    /// If the result value is set manually
    public var isSetManually: Bool

    init(result: TaskSubmitResultRepresentable, userID: User.ID, sessionID: TaskSession.ID? = nil) {
        self.taskID = result.taskID
        self.userID = userID
        self.timeUsed = result.timeUsed
        self.resultScore = result.score.clamped(to: 0...1)
        self.sessionID = sessionID
        self.isSetManually = false

        let numberOfDays = ScoreEvaluater.shared.daysUntillReview(score: resultScore)
        let interval = Double(numberOfDays) * 60 * 60 * 24
        self.revisitDate = Date().addingTimeInterval(interval)
    }
}

extension TaskResult: Content { }

extension TaskResult: Migration {

    public static func prepare(on conn: PostgreSQLConnection) -> EventLoopFuture<Void> {
        return PostgreSQLDatabase.create(TaskResult.self, on: conn) { builder in
            try addProperties(to: builder)

            builder.reference(from: \.taskID, to: \Task.id, onUpdate: .cascade, onDelete: .cascade)
            builder.reference(from: \.userID, to: \User.DatabaseModel.id, onUpdate: .cascade, onDelete: .setDefault)
            builder.reference(from: \.sessionID, to: \TaskSession.id, onUpdate: .cascade, onDelete: .setNull)

            builder.unique(on: \.sessionID, \.taskID)
        }.flatMap {
            PostgreSQLDatabase.update(TaskResult.self, on: conn) { builder in
                builder.deleteField(for: \.userID)
                builder.field(for: \.userID, type: .int, .default(1))
            }
        }
    }

    public static func revert(on connection: PostgreSQLConnection) -> Future<Void> {
        return PostgreSQLDatabase.delete(TaskResult.self, on: connection)
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

struct TaskResultUniqueMigration: PostgreSQLMigration {
    static func prepare(on conn: PostgreSQLConnection) -> EventLoopFuture<Void> {
        return PostgreSQLDatabase.update(TaskResult.self, on: conn) { builder in
            builder.unique(on: \.sessionID, \.taskID)
        }
    }
    static func revert(on conn: PostgreSQLConnection) -> EventLoopFuture<Void> {
        return conn.future()
    }
}

extension TaskResult {
    struct IsSetManuallyMigration: PostgreSQLMigration {

        static func prepare(on conn: PostgreSQLConnection) -> EventLoopFuture<Void> {
            PostgreSQLDatabase.update(TaskResult.self, on: conn) { builder in
                builder.field(for: \.isSetManually, type: .bool, .default(.literal(.boolean(.false))))
            }
        }

        static func revert(on conn: PostgreSQLConnection) -> EventLoopFuture<Void> {
            PostgreSQLDatabase.update(TaskResult.self, on: conn) { builder in
                builder.deleteField(for: \.isSetManually)
            }
        }
    }
}
