//
//  TaskResult+testable.swift
//  KognitaCoreTests
//
//  Created by Mats Mollestad on 30/04/2019.
//

import Vapor
import FluentKit
import Crypto
@testable import KognitaCore

extension TaskResult {
    /// Creates a `TaskResult`for testing
    /// - Parameters:
    ///   - task: The task to create the result for
    ///   - sessionID: The session ID the result is associated with
    ///   - user: The user the result is associated with
    ///   - score: The score fo the result
    ///   - conn: The database connection
    /// - Throws: If the database query fails
    /// - Returns: A `TaskResult`
    public static func create(task: TaskDatabaseModel, sessionID: TaskSession.IDValue, user: User, score: Double = 1, on database: Database) throws -> TaskResult {
        let practiceResult = TaskSessionResult(
            result: "",
            score: score,
            progress: 0
        )
        let submit = TypingTask.Submit(timeUsed: .random(in: 10...60), knowledge: 0, taskIndex: 0, answer: "Dummy answer")

        let submitResult = try TaskSubmitResult(submit: submit, result: practiceResult, taskID: task.requireID())

        let result = TaskResult.DatabaseModel(result: submitResult, userID: user.id, sessionID: sessionID)

        return try result.save(on: database)
            .flatMapThrowing { try result.content() }
            .wait()
    }
}
