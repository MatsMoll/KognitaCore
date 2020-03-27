import Vapor
import FluentPostgreSQL

enum TaskSolutionRepositoryError: String, Debuggable {

    var identifier: String {
        return "TaskSolutionRepositoryError.\(self.rawValue)"
    }

    var reason: String {
        switch self {
        case .toFewSolutions: return "There are to few solutions"
        }
    }

    case toFewSolutions
}


extension TaskSolution {

    public final class DatabaseRepository: TaskSolutionRepositoring {

        struct Query {
            struct SolutionID: Codable {
                let solutionID: TaskSolution.ID
                let userID: User.ID
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

        public static func create(from content: TaskSolution.Create.Data, by user: User?, on conn: DatabaseConnectable) throws -> EventLoopFuture<TaskSolution.Create.Response> {

            guard let user = user else { throw Abort(.unauthorized) }

            return try TaskSolution(
                data: TaskSolution.Create.Data(
                    solution: content.solution,
                    presentUser: true,
                    taskID: content.taskID
                ),
                creatorID: user.requireID()
            )
            .save(on: conn)
            .flatMap { solution in

                try User.DatabaseRepository
                    .isModerator(user: user, taskID: content.taskID, on: conn)
                    .flatMap {
                        solution.isApproved = true
                        try solution.approvedBy = user.requireID()
                        return solution.save(on: conn)
                            .transform(to: .init())
                }.catchMap { _ in .init() }
            }
        }

        public static func solutions(for taskID: Task.ID, for user: User, on conn: DatabaseConnectable) -> EventLoopFuture<[TaskSolution.Response]> {

            return conn.databaseConnection(to: .psql).flatMap { psqlConn in

                psqlConn
                    .raw(Query.taskSolutionForTaskID)
                    .bind(taskID)
                    .all(decoding: Query.Response.self)
                    .flatMap { solutions in

                        psqlConn.select()
                            .column(\TaskSolution.Pivot.Vote.solutionID)
                            .column(\TaskSolution.Pivot.Vote.userID)
                            .from(TaskSolution.Pivot.Vote.self)
                            .join(\TaskSolution.Pivot.Vote.solutionID, to: \TaskSolution.id)
                            .where(\TaskSolution.taskID == taskID)
                            .all(decoding: Query.SolutionID.self)
                            .map { (votes: [Query.SolutionID]) in

                                let counts = votes.count(equal: \.solutionID)

                                return solutions.map { solution in
                                    if solution.presentUser == false {
                                        solution.creatorUsername = nil
                                    }
                                    return TaskSolution.Response(
                                        queryResponse: solution,
                                        numberOfVotes: counts[solution.id] ?? 0,
                                        userHasVoted: votes.contains(where: { vote in vote.userID == user.id && vote.solutionID == solution.id })
                                    )
                                }
                                .sorted(by: { first, second in first.numberOfVotes > second.numberOfVotes })
                        }
                }
            }
        }

        public static func upvote(for solutionID: TaskSolution.ID, by user: User, on conn: DatabaseConnectable) throws -> EventLoopFuture<Void> {
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

        public static func update(model: TaskSolution, to data: TaskSolution.Update.Data, by user: User, on conn: DatabaseConnectable) throws -> EventLoopFuture<TaskSolution.Update.Response> {
            if try model.creatorID == user.requireID() {
                try model.update(with: data)
                return model.save(on: conn).transform(to: .init())
            } else {
                return try User.DatabaseRepository.isModerator(user: user, taskID: model.taskID, on: conn).flatMap {
                    try model.update(with: data)
                    return model.save(on: conn).transform(to: .init())
                }
            }
        }

        public static func delete(model: TaskSolution, by user: User?, on conn: DatabaseConnectable) throws -> EventLoopFuture<Void> {
            guard let user = user else {
                throw Abort(.unauthorized)
            }

            return TaskSolution.query(on: conn)
                .filter(\.taskID == model.taskID)
                .count()
                .flatMap { numberOfSolutions in

                    guard numberOfSolutions > 1 else { throw TaskSolutionRepositoryError.toFewSolutions }

                    if try model.creatorID == user.requireID() {
                        return model.delete(on: conn)
                    } else {
                        return try User.DatabaseRepository.isModerator(user: user, taskID: model.taskID, on: conn).flatMap {
                            model.delete(on: conn)
                        }
                    }
            }
        }

        public static func approve(for solutionID: TaskSolution.ID, by user: User, on conn: DatabaseConnectable) throws -> EventLoopFuture<Void> {

            TaskSolution
                .find(solutionID, on: conn)
                .unwrap(or: Abort(.badRequest))
                .flatMap { (solution: TaskSolution) in

                    try User.DatabaseRepository
                        .isModerator(user: user, taskID: solution.taskID, on: conn)
                        .flatMap {

                            try solution.approve(by: user)
                                .save(on: conn)
                    }
            }
            .transform(to: ())
        }
    }
}
