//
//  NumberInputTask.swift
//  App
//
//  Created by Mats Mollestad on 20/03/2019.
//

import Vapor
import FluentPostgreSQL

public final class NumberInputTask: PostgreSQLModel {

    public static let actionDescription = "Skriv inn et svar"

    public var id: Int?

    // The correct value
    public var correctAnswer: Double

    // The unit the answer is given in
    public var unit: String?

    init(correctAnswer: Double, unit: String? = nil, taskId: Task.ID? = nil) {
        self.correctAnswer = correctAnswer
        self.unit = unit
        self.id = taskId
    }

    init(content: NumberInputTaskCreateContent, task: Task) throws {
        self.correctAnswer = content.correctAnswer
        self.unit = content.unit
        self.id = try task.requireID()
    }
}

extension NumberInputTask: Parameter { }

extension NumberInputTask: PostgreSQLMigration {
    public static func prepare(on conn: PostgreSQLConnection) -> Future<Void> {
        return PostgreSQLDatabase.create(NumberInputTask.self, on: conn) { builder in
            try addProperties(to: builder)
            builder.reference(from: \.id, to: \Task.id)
        }
    }
}

extension NumberInputTask {

    var task: Parent<NumberInputTask, Task>? {
        return parent(\.id)
    }


    func evaluate(for answer: NumberInputTaskSubmit) -> PracticeSessionResult<NumberInputTaskSubmitResponse> {
        let wasCorrect = correctAnswer == answer.answer
        return PracticeSessionResult(
            result: .init(
                correctAnswer: correctAnswer,
                wasCorrect: wasCorrect
            ),
            unforgivingScore: wasCorrect ? 1 : -1,
            forgivingScore: wasCorrect ? 1 : 0,
            progress: 0
        )
    }
}

public struct NumberInputTaskContent: Content {
    public let task: Task
    public let input: NumberInputTask
}

public struct NumberInputTaskSubmit: Content, TaskSubmitable {
    public let timeUsed: TimeInterval
    public let answer: Double
}

public struct NumberInputTaskSubmitResponse: Content {
    public let correctAnswer: Double
    public let wasCorrect: Bool
}
