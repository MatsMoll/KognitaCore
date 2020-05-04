//
//  DiscussionTask.swift
//  Core
//
//  Created by Eskild Brobak on 25/02/2020.
//

import FluentPostgreSQL
import Vapor

public final class TaskDiscussion: KognitaCRUDModel, Validatable {

    public var id: Int?

    public var userID: User.ID

    public var description: String

    public var taskID: Task.ID

    public var createdAt: Date?

    public var updatedAt: Date?

    init(data: TaskDiscussion.Create.Data, userID: User.ID) throws {
        self.description = data.description
        self.taskID = data.taskID
        self.userID = userID
        try validate()
    }

    func update(with data: TaskDiscussion.Update.Data) throws {
        description = data.description
        try validate()
    }

    public static func prepare(on conn: PostgreSQLConnection) -> EventLoopFuture<Void> {
        PostgreSQLDatabase.create(TaskDiscussion.self, on: conn) { builder in

            try addProperties(to: builder)

            builder.reference(from: \.taskID, to: \Task.id, onUpdate: .cascade, onDelete: .cascade)
            builder.reference(from: \.userID, to: \User.id, onUpdate: .cascade, onDelete: .setDefault)
        }.flatMap {
            PostgreSQLDatabase.update(TaskDiscussion.self, on: conn) { builder in
                builder.deleteField(for: \.userID)
                builder.field(for: \.userID, type: .int, .default(1))
            }
        }
    }

    public static func validations() throws -> Validations<TaskDiscussion> {
        var validations = Validations(TaskDiscussion.self)
        try validations.add(\.description, .count(4...))
        try validations.add(\.userID, .range(1...))
        try validations.add(\.taskID, .range(1...))
        return validations
    }
}

extension TaskDiscussion: ModelParameterRepresentable {}
