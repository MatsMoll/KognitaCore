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
        builder.reference(from: \.id, to: \Task.id)
    }
}

extension FlashCardTask: Content { }
extension FlashCardTask: Parameter { }

extension FlashCardTask {
    var task: Parent<FlashCardTask, Task>? {
        return parent(\.id)
    }

    func content(on conn: DatabaseConnectable) -> Future<TaskPreviewContent> {
        return FlashCardTask.DatabaseRepository.content(for: self, on: conn)
    }
}
