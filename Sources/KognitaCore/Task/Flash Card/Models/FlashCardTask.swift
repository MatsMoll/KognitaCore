//
//  FlashCardTask.swift
//  App
//
//  Created by Mats Mollestad on 31/03/2019.
//
import FluentKit
import Vapor

internal final class FlashCardTask: KognitaCRUDModel {

    public static var tableName: String = "FlashCardTask"

    static let actionDescriptor = "Les spørsmålet og skriv et passende svar"

    @DBID(custom: "id", generatedBy: .user)
    public var id: Int?

    @Timestamp(key: "createdAt", on: .create)
    public var createdAt: Date?

    @Timestamp(key: "updatedAt", on: .update)
    public var updatedAt: Date?

    public init(taskId: Task.ID) {
        self.id = taskId
    }

    init(task: TaskDatabaseModel) throws {
        self.id = try task.requireID()
    }

    public init() {}
}

extension FlashCardTask: Content { }

extension FlashCardTask {
    enum Migrations {}
}

extension FlashCardTask.Migrations {
    struct Create: KognitaModelMigration {

        typealias Model = FlashCardTask

        var subclassSchema: String? = TaskDatabaseModel.schema

        func build(schema: SchemaBuilder) -> SchemaBuilder {
            schema.defaultTimestamps()
        }
    }
}
