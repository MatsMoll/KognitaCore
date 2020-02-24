import Vapor
import FluentPostgreSQL

extension TaskSolution {

    public final class Repository: RetriveAllModelsRepository {


        struct Query {
            struct SolutionID: Codable {
                let solutionID: TaskSolution.ID
            }

            final class Response: Codable {
                public let id: TaskSolution.ID
                public let createdAt: Date?
                public let solution: String
                public var creatorUsername: String?
                public let presentUser: Bool
                public let approvedBy: String?
            }

            static let taskSolutionForTaskID = #"SELECT "sol"."id", "sol"."createdAt", "sol"."presentUser", "sol"."solution", "creator"."username" AS "creatorUsername", "approved"."username" AS "approvedBy" FROM "TaskSolution" AS "sol" INNER JOIN "User" AS "creator" ON "sol"."creatorID" = "creator"."id" LEFT JOIN "User" AS "approved" ON "sol"."approvedBy" = "approved"."id" INNER JOIN "Task" ON "sol"."taskID" = "Task"."id" WHERE "Task"."id" = ($1)"#
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
                    .all(decoding: Query.Response.self)
                    .flatMap { solutions in

                        psqlConn.select()
                            .column(\TaskSolution.Pivot.Vote.solutionID)
                            .from(TaskSolution.Pivot.Vote.self)
                            .join(\TaskSolution.Pivot.Vote.solutionID, to: \TaskSolution.id)
                            .where(\TaskSolution.taskID == taskID)
                            .all(decoding: Query.SolutionID.self)
                            .map { (votes: [Query.SolutionID]) in

                                let counts = votes.count(\.solutionID)

                                return solutions.map { solution in
                                    if solution.presentUser == false {
                                        solution.creatorUsername = nil
                                    }
                                    return TaskSolution.Response(
                                        queryResponse: solution,
                                        numberOfVotes: counts[solution.id] ?? 0
                                    )
                                }
                        }
                }
            }
        }

        public static func vote(for solutionID: TaskSolution.ID, by user: User, on conn: DatabaseConnectable) throws -> EventLoopFuture<Void> {
            try TaskSolution.Pivot.Vote(userID: user.requireID(), solutionID: solutionID)
                .create(on: conn)
                .transform(to: ())
        }

        public static func revokeVote(for solutionID: TaskSolution.ID, by user: User, on conn: DatabaseConnectable) throws -> EventLoopFuture<Void> {
            try TaskSolution.Pivot.Vote.query(on: conn)
                .filter(\.userID == user.requireID())
                .filter(\.solutionID == solutionID)
                .first()
                .unwrap(or: Abort(.badRequest))
                .flatMap { vote in
                    vote.delete(on: conn)
            }
        }
    }

}
