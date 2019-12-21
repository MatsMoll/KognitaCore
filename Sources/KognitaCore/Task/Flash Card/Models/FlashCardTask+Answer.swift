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
    
    public var id: Int?

    public var sessionID: PracticeSession.ID

    public var taskID: FlashCardTask.ID

    public var answer: String

    init(sessionID: PracticeSession.ID, taskID: FlashCardTask.ID, answer: String) {
        self.sessionID = sessionID
        self.taskID = taskID
        self.answer = answer
    }
}

extension FlashCardAnswer: Migration {
    public static func prepare(on conn: PostgreSQLConnection) -> Future<Void> {
        return PostgreSQLDatabase.create(FlashCardAnswer.self, on: conn) { builder in
            try addProperties(to: builder)
            builder.reference(from: \.sessionID, to: \PracticeSession.id, onUpdate: .cascade, onDelete: .cascade)
            builder.reference(from: \.taskID, to: \FlashCardTask.id, onUpdate: .cascade, onDelete: .cascade)
        }
    }

    public static func revert(on connection: PostgreSQLConnection) -> Future<Void> {
        return PostgreSQLDatabase.delete(FlashCardAnswer.self, on: connection)
    }
}
