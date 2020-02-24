//
//  TaskSolution.swift
//  KognitaCore
//
//  Created by Mats Mollestad on 20/10/2019.
//

import Vapor
import FluentPostgreSQL

/// One solution to a `Task`
public final class TaskSolution: KognitaPersistenceModel {

    public var id: Int?

    public var createdAt: Date?

    public var updatedAt: Date?

    public var solution: String

    public var creatorID: User.ID

    public var isApproved: Bool

    public var approvedBy: User.ID?

    public var taskID: Task.ID

    public var presentUser: Bool

    init(data: Create.Data, creatorID: User.ID) {
        self.solution = data.solution
        self.presentUser = data.presentUser
        self.taskID = data.taskID
        self.creatorID = creatorID
        self.isApproved = false
        self.approvedBy = nil
    }

    public static func prepare(on conn: PostgreSQLConnection) -> EventLoopFuture<Void> {
        PostgreSQLDatabase.create(TaskSolution.self, on: conn) { builder in
            try addProperties(to: builder)

            builder.reference(from: \.taskID, to: \Task.id)
            builder.reference(from: \.creatorID, to: \User.id, onUpdate: .cascade, onDelete: .setDefault)
            builder.reference(from: \.approvedBy, to: \User.id, onUpdate: .cascade, onDelete: .setDefault)
        }.flatMap {
            PostgreSQLDatabase.update(TaskSolution.self, on: conn) { builder in
                builder.deleteField(for: \.creatorID)
                builder.field(for: \.creatorID, type: .int, .default(1))
            }
        }
    }
}
