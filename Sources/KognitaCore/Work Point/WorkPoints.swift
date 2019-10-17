//
//  WorkPoint.swift
//  KognitaCore
//
//  Created by Mats Mollestad on 25/09/2019.
//

import Vapor
import FluentPostgreSQL

public final class WorkPoints: KognitaPersistenceModel {

    public var id: Int?

    public var userID: User.ID

    public var taskResultID: TaskResult.ID?

    public var points: Int

    public var boostAmount: Double

    public var updatedAt: Date?

    public var createdAt: Date?

    public static func addTableConstraints(to builder: SchemaCreator<WorkPoints>) {
        builder.reference(from: \.userID, to: \User.id, onUpdate: .cascade, onDelete: .cascade)
        builder.reference(from: \.taskResultID, to: \TaskResult.id, onUpdate: .cascade, onDelete: .cascade)
    }

    init(taskResult: TaskResult, boostAmount: Double) throws {
        guard let userID = taskResult.userID else { throw Abort(.badRequest) }
        self.userID = userID
        self.taskResultID = taskResult.id
//        self.points = 0
        self.points = Int(round((taskResult.resultScore * 40 + min(taskResult.timeUsed / 5, 120)) * boostAmount))
        self.boostAmount = boostAmount
    }
}

extension WorkPoints : Content {}

struct TaskResultWorkPointsMigration: PostgreSQLMigration {

    static func revert(on conn: PostgreSQLConnection) -> EventLoopFuture<Void> {
        return conn.future()
    }

    static func prepare(on conn: PostgreSQLConnection) -> EventLoopFuture<Void> {
        return TaskResult.query(on: conn).all()
            .flatMap { results in
                try results.map { try WorkPoints(taskResult: $0, boostAmount: 1).save(on: conn) }
                    .flatten(on: conn)
                    .transform(to: ())
        }
    }
}
