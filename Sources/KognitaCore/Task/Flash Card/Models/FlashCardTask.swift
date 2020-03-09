//
//  FlashCardTask.swift
//  App
//
//  Created by Mats Mollestad on 31/03/2019.
//

import FluentPostgreSQL
import Vapor

public final class FlashCardTask: KognitaCRUDModel {

    static let actionDescriptor = "Les spørsmålet og skriv et passende svar"

    public var id: Int?
    
    public var createdAt: Date?
    
    public var updatedAt: Date?
    

    public init(taskId: Task.ID) {
        self.id = taskId
    }
    
    public init(task: Task) throws {
        self.id = try task.requireID()
    }
    
    public static func addTableConstraints(to builder: SchemaCreator<FlashCardTask>) {
        builder.reference(from: \.id, to: \Task.id, onUpdate: .cascade, onDelete: .cascade)
    }
}

extension FlashCardTask: Content { }
extension FlashCardTask: ModelParameterRepresentable { }

extension FlashCardTask {
    var task: Parent<FlashCardTask, Task>? {
        return parent(\.id)
    }

    func content(on conn: DatabaseConnectable) -> EventLoopFuture<TaskPreviewContent> {
        return FlashCardTask.DatabaseRepository.content(for: self, on: conn)
    }
}

extension FlashCardTask {
    enum Migration {
        struct TaskIDReference: PostgreSQLMigration {

            static func prepare(on conn: PostgreSQLConnection) -> EventLoopFuture<Void> {
                PostgreSQLDatabase.update(FlashCardTask.self, on: conn) { builder in
                    builder.deleteReference(from: \.id, to: \Task.id)
                    builder.reference(from: \.id, to: \Task.id, onUpdate: .cascade, onDelete: .cascade)
                }
            }

            static func revert(on conn: PostgreSQLConnection) -> EventLoopFuture<Void> {
                conn.future()
            }
        }
    }
}
