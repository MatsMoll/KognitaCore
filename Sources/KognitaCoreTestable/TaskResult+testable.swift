//
//  TaskResult+testable.swift
//  KognitaCoreTests
//
//  Created by Mats Mollestad on 30/04/2019.
//

import Vapor
import FluentPostgreSQL
import Crypto
@testable import KognitaCore


extension TaskResult {
    public static func create(task: Task, sessionID: TaskSession.ID, user: User, score: Double = 1, on conn: PostgreSQLConnection) throws -> TaskResult {
        let practiceResult = TaskSessionResult(
            result: "",
            score: score,
            progress: 0
        )
        let submit = FlashCardTask.Submit(timeUsed: .random(in: 10...60), knowledge: 0, taskIndex: 0, answer: "Dummy answer")

        let submitResult = try TaskSubmitResult(submit: submit, result: practiceResult, taskID: task.requireID())

        return try TaskResult(result: submitResult, userID: user.requireID(), sessionID: sessionID)
            .save(on: conn)
            .wait()
    }
}
