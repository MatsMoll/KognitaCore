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

extension TaskSolution {

    public final class Response: Content {
        public let createdAt: Date?
        public let solution: String
        public var creatorUsername: String?
        public let presentUser: Bool
        public let approvedBy: String?
    }

    public enum Create {
        public struct Data {
            let solution: String
            let presentUser: Bool
            var taskID: Task.ID
        }
        public struct Response: Content {}
    }

    public final class Repository: RetriveAllModelsRepository {

        struct Query {
            static let taskSolutionForTaskID = #"SELECT "sol"."createdAt", "sol"."presentUser", "sol"."solution", "creator"."username" AS "creatorUsername", "approved"."username" AS "approvedBy" FROM "TaskSolution" AS "sol" INNER JOIN "User" AS "creator" ON "sol"."creatorID" = "creator"."id" LEFT JOIN "User" AS "approved" ON "sol"."approvedBy" = "approved"."id" INNER JOIN "Task" ON "sol"."taskID" = "Task"."id" WHERE "Task"."id" = ($1)"#
        }

        public typealias Model = TaskSolution
        public typealias ResponseModel = TaskSolution

        public static func create(from content: TaskSolution.Create.Data, by user: User?, on conn: DatabaseConnectable) throws -> EventLoopFuture<TaskSolution.Create.Response> {

            guard let user = user else { throw Abort(.unauthorized) }

            return try TaskSolution(data: content, creatorID: user.requireID())
                .save(on: conn)
                .transform(to: .init())
        }

        public static func solutions(for taskID: Task.ID, on conn: DatabaseConnectable) -> EventLoopFuture<[TaskSolution.Response]> {
            return conn.databaseConnection(to: .psql).flatMap { psqlConn in
                psqlConn
                    .raw(Query.taskSolutionForTaskID)
                    .bind(taskID)
                    .all(decoding: TaskSolution.Response.self)
                    .map { solutions in
                        solutions.map { solution in
                            if solution.presentUser == false {
                                solution.creatorUsername = nil
                            }
                            return solution
                        }
                }
            }
        }
    }
}
