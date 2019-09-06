//
//  NumberInputTask.swift
//  App
//
//  Created by Mats Mollestad on 20/03/2019.
//

import Vapor
import FluentPostgreSQL

public final class NumberInputTask : KognitaCRUDModel {

    public static let actionDescription = "Skriv inn et svar"

    public var id: Int?

    // The correct value
    public var correctAnswer: Double

    // The unit the answer is given in
    public var unit: String?
    
    public var createdAt: Date?
    
    public var updatedAt: Date?
    

    init(correctAnswer: Double, unit: String? = nil, taskId: Task.ID? = nil) {
        self.correctAnswer = correctAnswer
        self.unit = unit
        self.id = taskId
    }

    init(content: Create.Data, task: Task) throws {
        self.correctAnswer = content.correctAnswer
        self.unit = content.unit
        self.id = try task.requireID()
    }
    
    public static func addTableConstraints(to builder: SchemaCreator<NumberInputTask>) {
        builder.reference(from: \.id, to: \Task.id)
    }
}

extension NumberInputTask: Parameter { }
extension NumberInputTask: Content { }

extension NumberInputTask {

    var task: Parent<NumberInputTask, Task>? {
        return parent(\.id)
    }

    func evaluate(for answer: NumberInputTask.Submit.Data) -> PracticeSessionResult<NumberInputTask.Submit.Response> {
        let wasCorrect = correctAnswer == answer.answer
        return PracticeSessionResult.init(
            result: .init(
                correctAnswer: correctAnswer,
                wasCorrect: wasCorrect
            ),
            score: wasCorrect ? 1 : 0,
            progress: 0
        )
    }
}

