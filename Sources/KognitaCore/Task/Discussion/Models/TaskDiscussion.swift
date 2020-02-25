//
//  DiscussionTask.swift
//  Core
//
//  Created by Eskild Brobak on 25/02/2020.
//

import FluentPostgreSQL
import Vapor

public final class TaskDiscussion : KognitaCRUDModel {

    public var id: Int?

    public var userID: User.ID

    public var description: String

    public var taskID: Task.ID

    public var createdAt: Date?

    public var updatedAt: Date?

    init(data: TaskDiscussion.Create.Data, userID: User.ID) {
        self.description = data.description
        self.taskID = data.taskID
        self.userID = userID
    }

    func update(with data: TaskDiscussion.Update.Data) {
        description = data.description
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
}
