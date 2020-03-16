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

    public var choiseID: MultipleChoiseTaskChoise.ID

    public init(answerID: TaskAnswer.ID, choiseID: MultipleChoiseTaskChoise.ID) {
        self.id = answerID
        self.choiseID = choiseID
    }
}

extension MultipleChoiseTaskAnswer: Migration {
    public static func prepare(on conn: PostgreSQLConnection) -> EventLoopFuture<Void> {
        return PostgreSQLDatabase.create(MultipleChoiseTaskAnswer.self, on: conn) { builder in
            try addProperties(to: builder)

            builder.reference(from: \.id, to: \TaskAnswer.id, onUpdate: .cascade, onDelete: .cascade)
            builder.reference(from: \.choiseID, to: \MultipleChoiseTaskChoise.id, onUpdate: .cascade, onDelete: .cascade)
        }
    }

    public static func revert(on connection: PostgreSQLConnection) -> EventLoopFuture<Void> {
        return PostgreSQLDatabase.delete(MultipleChoiseTaskAnswer.self, on: connection)
    }
}

