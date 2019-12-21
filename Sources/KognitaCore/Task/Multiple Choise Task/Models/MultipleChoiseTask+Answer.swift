//
//  MultipleChoiseTask+Answer.swift
//  KognitaCore
//
//  Created by Mats Mollestad on 25/10/2019.
//

import Vapor
import FluentPostgreSQL

/// A submittet choise in a task
public final class MultipleChoiseTaskAnswer: PostgreSQLModel, Codable {

    public var id: Int?

    public var sessionID: PracticeSession.ID

    public var choiseID: MultipleChoiseTaskChoise.ID

    public init(sessionID: PracticeSession.ID, choiseID: MultipleChoiseTaskChoise.ID) {
        self.sessionID = sessionID
        self.choiseID = choiseID
    }
}

extension MultipleChoiseTaskAnswer: Migration {
    public static func prepare(on conn: PostgreSQLConnection) -> Future<Void> {
        return PostgreSQLDatabase.create(MultipleChoiseTaskAnswer.self, on: conn) { builder in
            try addProperties(to: builder)
            builder.reference(from: \.sessionID, to: \PracticeSession.id, onUpdate: .cascade, onDelete: .cascade)
            builder.reference(from: \.choiseID, to: \MultipleChoiseTaskChoise.id, onUpdate: .cascade, onDelete: .cascade)
        }
    }

    public static func revert(on connection: PostgreSQLConnection) -> Future<Void> {
        return PostgreSQLDatabase.delete(MultipleChoiseTaskAnswer.self, on: connection)
    }
}

