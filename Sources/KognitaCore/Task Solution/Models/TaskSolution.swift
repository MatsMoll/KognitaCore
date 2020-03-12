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

    init(data: Create.Data, creatorID: User.ID) throws {
        self.solution = try data.solution.cleanXSS(whitelist: .basicWithImages())
        self.presentUser = data.presentUser
        self.taskID = data.taskID
        self.creatorID = creatorID
        self.isApproved = false
        self.approvedBy = nil
    }

    public static func prepare(on conn: PostgreSQLConnection) -> EventLoopFuture<Void> {
        PostgreSQLDatabase.create(TaskSolution.self, on: conn) { builder in
            try addProperties(to: builder)

            builder.reference(from: \.taskID, to: \Task.id, onUpdate: .cascade, onDelete: .cascade)
            builder.reference(from: \.creatorID, to: \User.id, onUpdate: .cascade, onDelete: .setDefault)
            builder.reference(from: \.approvedBy, to: \User.id, onUpdate: .cascade, onDelete: .setDefault)
        }.flatMap {
            PostgreSQLDatabase.update(TaskSolution.self, on: conn) { builder in
                builder.deleteField(for: \.creatorID)
                builder.field(for: \.creatorID, type: .int, .default(1))
            }
        }
    }

    public func update(with data: TaskSolution.Update.Data) throws {
        if let solution = data.solution {
            self.solution = try solution.cleanXSS(whitelist: .basicWithImages())
        }
        if let presentUser = data.presentUser {
            self.presentUser = presentUser
        }
    }

    public func approve(by user: User) throws -> TaskSolution {
        guard approvedBy == nil else {
            return self
        }
        approvedBy = try user.requireID()
        isApproved = true
        return self
    }
}

extension TaskSolution {
    enum Migration {
        struct TaskIDDeleteReferance: PostgreSQLMigration {

            static func prepare(on conn: PostgreSQLConnection) -> EventLoopFuture<Void> {
                PostgreSQLDatabase.update(TaskSolution.self, on: conn) { builder in

                    builder.deleteReference(from: \.taskID, to: \Task.id)
                    builder.reference(from: \.taskID, to: \Task.id, onUpdate: .cascade, onDelete: .cascade)
                }
            }

            static func revert(on conn: PostgreSQLConnection) -> EventLoopFuture<Void> {
                conn.future()
            }
        }
    }
}
