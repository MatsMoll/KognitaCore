//
//  FlashCardTask.swift
//  App
//
//  Created by Mats Mollestad on 31/03/2019.
//

import FluentPostgreSQL
import Vapor

public final class FlashCardTask: PostgreSQLModel {

    static let actionDescriptor = "Svar på oppgaven og se om du har riktig"

    public var id: Int?

    init(task: Task) throws {
        self.id = try task.requireID()
    }
}

extension FlashCardTask: Migration {
    public static func prepare(on conn: PostgreSQLConnection) -> Future<Void> {
        return PostgreSQLDatabase.create(FlashCardTask.self, on: conn) { builder in
            try addProperties(to: builder)
            builder.reference(from: \.id, to: \Task.id)
        }
    }

    public static func revert(on connection: PostgreSQLConnection) -> Future<Void> {
        return PostgreSQLDatabase.delete(FlashCardTask.self, on: connection)
    }
}

extension FlashCardTask: Content { }
extension FlashCardTask: Parameter { }

extension FlashCardTask {
    var task: Parent<FlashCardTask, Task>? {
        return parent(\.id)
    }

    func content(on conn: DatabaseConnectable) -> Future<TaskPreviewContent> {
        return FlashCardRepository.shared.content(for: self, on: conn)
    }
}
