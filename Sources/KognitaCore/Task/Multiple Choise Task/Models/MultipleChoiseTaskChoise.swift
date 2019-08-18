//
//  MultipleChoiseTaskChoise.swift
//  App
//
//  Created by Mats Mollestad on 07/10/2018.
//

import Vapor
import FluentPostgreSQL

public final class MultipleChoiseTaskChoise: PostgreSQLModel {

    public var id: Int?

    /// The choise description
    public var choise: String

    /// A bool indication if it is correct or false
    public var isCorrect: Bool

    /// The id of the taks this choise relates to
    public var taskId: MultipleChoiseTask.ID

    init(choise: String, isCorrect: Bool) {
        self.choise = choise
        self.isCorrect = isCorrect
        self.taskId = 0
    }

    init(content: MultipleChoiseTaskChoiseContent, task: MultipleChoiseTask) throws {
        self.taskId = try task.requireID()
        self.choise = content.choise
        self.isCorrect = content.isCorrect

        self.choise.makeHTMLSafe()
    }
}

extension MultipleChoiseTaskChoise: Migration {
    public static func prepare(on conn: PostgreSQLConnection) -> Future<Void> {
        return PostgreSQLDatabase.create(MultipleChoiseTaskChoise.self, on: conn) { builder in
            builder.field(for: \.id, isIdentifier: true)
            builder.field(for: \.choise)
            builder.field(for: \.isCorrect)
            builder.field(for: \.taskId)

            builder.reference(from: \.taskId, to: \MultipleChoiseTask.id, onUpdate: .cascade, onDelete: .cascade)
        }
    }

    public static func revert(on connection: PostgreSQLConnection) -> Future<Void> {
        return PostgreSQLDatabase.delete(MultipleChoiseTaskChoise.self, on: connection)
    }
}

extension MultipleChoiseTaskChoise: Parameter { }

extension MultipleChoiseTaskChoise: Content { }
