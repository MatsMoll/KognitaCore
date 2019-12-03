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

//    public var helpAmount: Double // Should maybe be another table so it can not be voted by the same person twise

    public var taskID: Task.ID

    public var presentUser: Bool

    init(data: Create.Data, creatorID: User.ID) {
        self.solution = data.solution
        self.presentUser = data.presentUser
        self.taskID = data.taskID
        self.creatorID = creatorID
        self.isApproved = false
    }

    public static func addTableConstraints(to builder: SchemaCreator<TaskSolution>) {
        builder.reference(from: \.creatorID, to: \User.id)
        builder.reference(from: \.taskID, to: \Task.id)
        builder.reference(from: \.approvedBy, to: \User.id)
    }

    func response(on conn: DatabaseConnectable) -> EventLoopFuture<Response> {
        fatalError()
//            var response = Response(createdAt: createdAt, solution: solution, creatorName: nil, approvedBy: nil)
//            let approvedByID = approvedBy
//            if presentUser {
//                return User.Repository.find(creatorID, or: Abort(.internalServerError), on: conn)
//                    .flatMap { creator in
//                        response.creatorName = creator.name
//                        if let approvedByID = approvedByID {
//                            return User.Repository.find(approvedByID, or: Abort(.internalServerError), on: conn).map { user in
//                                response.approvedBy = user.name
//                                return response
//                            }
//                        } else {
//                            return conn.future(response)
//                        }
//                }
//            } else if let approvedByID = approvedByID {
//                return User.Repository.find(approvedByID, or: Abort(.internalServerError), on: conn).map { user in
//                    response.approvedBy = user.name
//                    return response
//                }
//            } else {
//                return conn.future(response)
//            }
    }
}

extension TaskSolution {

    public final class Response: Content {
        public let createdAt: Date?
        public let solution: String
        public var creatorName: String?
        public let presentUser: Bool
        public let approvedBy: String?
    }

    public struct Create: KognitaRequestData {
        public struct Data {
            let solution: String
            let presentUser: Bool
            var taskID: Task.ID
        }
        public struct Response: Content {}
    }

    public final class Repository: KognitaRepository {

        struct Query {
            static let taskSolutionForTaskID = #"SELECT "sol"."createdAt", "sol"."presentUser", "sol"."solution", "creator"."name" AS "creatorName", "approved"."name" AS "approvedBy" FROM "TaskSolution" AS "sol" INNER JOIN "User" AS "creator" ON "sol"."creatorID" = "creator"."id" LEFT JOIN "User" AS "approved" ON "sol"."approvedBy" = "approved"."id" INNER JOIN "Task" ON "sol"."taskID" = "Task"."id" WHERE "Task"."id" = ($1)"#
        }

        public typealias Model = TaskSolution

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
                                solution.creatorName = nil
                            }
                            return solution
                        }
                }
            }
        }
    }
}


extension TaskSolution {
    struct ConvertMigration: PostgreSQLMigration {
        static func prepare(on conn: PostgreSQLConnection) -> EventLoopFuture<Void> {
            Task.Repository.all(on: conn).flatMap { (tasks: [Task]) in
                return tasks.compactMap { (task: Task) -> Future<TaskSolution>? in
                    if let solution = task.solution, let id = task.id {
                        return TaskSolution(data: .init(solution: solution, presentUser: true, taskID: id), creatorID: task.creatorId)
                            .save(on: conn)
                    } else {
                        return nil
                    }
                }
                .flatten(on: conn)
                .transform(to: ())
            }
        }

        static func revert(on conn: PostgreSQLConnection) -> EventLoopFuture<Void> {
            conn.future()
        }
    }
}
