//
//  FlashCardTask+Answer.swift
//  KognitaCore
//
//  Created by Mats Mollestad on 25/10/2019.
//

import Vapor
import FluentPostgreSQL

/// A submitted answer form a `FlashCardTask`
public final class FlashCardAnswer: PostgreSQLModel, Codable {

    public typealias Database = PostgreSQLDatabase

    public var id: Int?

    public var taskID: FlashCardTask.ID

    public var answer: String

    init(answerID: TaskAnswer.ID, taskID: FlashCardTask.ID, answer: String) {
        self.id = answerID
        self.taskID = taskID
        self.answer = answer
    }
}

extension FlashCardAnswer: Migration {
    public static func prepare(on conn: PostgreSQLConnection) -> EventLoopFuture<Void> {
        return PostgreSQLDatabase.create(FlashCardAnswer.self, on: conn) { builder in
            try addProperties(to: builder)

            builder.reference(from: \.id, to: \TaskAnswer.id, onUpdate: .cascade, onDelete: .cascade)
            builder.reference(from: \.taskID, to: \FlashCardTask.id, onUpdate: .cascade, onDelete: .cascade)
        }
    }

    public static func revert(on connection: PostgreSQLConnection) -> EventLoopFuture<Void> {
        return PostgreSQLDatabase.delete(FlashCardAnswer.self, on: connection)
    }
}
