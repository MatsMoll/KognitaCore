//
//  NumberInputTaskResult.swift
//  App
//
//  Created by Mats Mollestad on 01/04/2019.
//

import Vapor
import FluentPostgreSQL

public protocol TaskSubmitable {
    var timeUsed: TimeInterval { get }
}

public protocol TaskSubmitResultable {

    var unforgivingScore: Double { get }

    var forgivingScore: Double { get }
}


/// A Result from a executed task
public final class TaskResult: PostgreSQLModel {

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

    public var timeUsed: TimeInterval

    public var sessionID: PracticeSession.ID?


    init(result: TaskSubmitResult, userID: User.ID, session: PracticeSession? = nil) {
        self.taskID = result.taskID
        self.userID = userID
        self.timeUsed = result.submit.timeUsed
        self.resultScore = result.result.unforgivingScore.clamped(to: 0...1)
        self.sessionID = session?.id

        let referanceDate = session?.createdAt ?? Date()

        let numberOfDays = ScoreEvaluater.shared.daysUntillReview(score: resultScore)
        let interval = Double(numberOfDays) * 60 * 60 * 24
        self.revisitDate = referanceDate.addingTimeInterval(interval)
    }
}

extension TaskResult: Content { }

extension TaskResult: Migration {

    public static func prepare(on conn: PostgreSQLConnection) -> Future<Void> {
        return PostgreSQLDatabase.create(TaskResult.self, on: conn) { builder in
            try addProperties(to: builder)

            builder.reference(from: \.taskID, to: \Task.id, onUpdate: .cascade, onDelete: .cascade)
            builder.reference(from: \.userID, to: \User.id, onUpdate: .cascade, onDelete: .setNull)
            builder.reference(from: \.sessionID, to: \PracticeSession.id, onUpdate: .cascade, onDelete: .setNull)
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
