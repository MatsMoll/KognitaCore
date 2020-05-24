import Vapor
import FluentPostgreSQL
import FluentSQL

enum TaskSolutionRepositoryError: String, Debuggable {

    var identifier: String {
        return "TaskSolutionRepositoryError.\(self.rawValue)"
    }

    var reason: String {
        switch self {
        case .toFewSolutions: return "There are too few solutions"
        }
    }

    case toFewSolutions
}

extension TaskSolution {

    public struct DatabaseRepository: TaskSolutionRepositoring, DatabaseConnectableRepository {

        public let conn: DatabaseConnectable
        private var userRepository: some UserRepository { User.DatabaseRepository(conn: conn) }

        struct Query {
            struct SolutionID: Codable {
                let solutionID: TaskSolution.ID
                let userID: User.ID
            }

            final class Response: Codable {
                public let id: TaskSolution.ID
                public let createdAt: Date?
                public let solution: String
                public var creatorID: User.ID
                public var creatorUsername: String?
                public let presentUser: Bool
                public let approvedBy: String?
            }

            static let taskSolutionForTaskID = #"SELECT "sol"."id", "sol"."createdAt", "sol"."presentUser", "sol"."solution", "creator"."id" AS "creatorID", "creator"."username" AS "creatorUsername", "approved"."username" AS "approvedBy" FROM "TaskSolution" AS "sol" INNER JOIN "User" AS "creator" ON "sol"."creatorID" = "creator"."id" LEFT JOIN "User" AS "approved" ON "sol"."approvedBy" = "approved"."id" INNER JOIN "Task" ON "sol"."taskID" = "Task"."id" WHERE "Task"."id" = ($1)"#
        }

        public func create(from content: TaskSolution.Create.Data, by user: User?) throws -> EventLoopFuture<TaskSolution.Create.Response> {

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

                try self
                    .userRepository
                    .isModerator(user: user, taskID: content.taskID)
                    .flatMap {
                        solution.isApproved = true
                        try solution.approvedBy = user.requireID()
                        return solution.save(on: self.conn)
                            .transform(to: .init())
                }.catchMap { _ in .init() }
            }
        }

        public func solutions(for taskID: Task.ID, for user: User) -> EventLoopFuture<[TaskSolution.Response]> {

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

        public func upvote(for solutionID: TaskSolution.ID, by user: User) throws -> EventLoopFuture<Void> {
            try TaskSolution.Pivot.Vote(userID: user.requireID(), solutionID: solutionID)
                .create(on: conn)
                .transform(to: ())
        }

        public func revokeVote(for solutionID: TaskSolution.ID, by user: User) throws -> EventLoopFuture<Void> {
            try TaskSolution.Pivot.Vote.query(on: conn)
                .filter(\.userID == user.requireID())
                .filter(\.solutionID == solutionID)
                .first()
                .unwrap(or: Abort(.badRequest))
                .flatMap { vote in
                    vote.delete(on: self.conn)
            }
        }

        public func update(model: TaskSolution, to data: TaskSolution.Update.Data, by user: User) throws -> EventLoopFuture<TaskSolution.Update.Response> {
            if try model.creatorID == user.requireID() {
                try model.update(with: data)
                return model.save(on: conn).transform(to: .init())
            } else {
                return try self.userRepository.isModerator(user: user, taskID: model.taskID).flatMap {
                    try model.update(with: data)
                    return model.save(on: self.conn).transform(to: .init())
                }
            }
        }

        public func delete(model: TaskSolution, by user: User?) throws -> EventLoopFuture<Void> {
            guard let user = user else {
                throw Abort(.unauthorized)
            }

            return TaskSolution.query(on: conn)
                .filter(\.taskID == model.taskID)
                .count()
                .flatMap { numberOfSolutions in

                    guard numberOfSolutions > 1 else { throw TaskSolutionRepositoryError.toFewSolutions }

                    if try model.creatorID == user.requireID() {
                        return model.delete(on: self.conn)
                    } else {
                        return try self.userRepository.isModerator(user: user, taskID: model.taskID).flatMap {
                            model.delete(on: self.conn)
                        }
                    }
            }
        }

        public func approve(for solutionID: TaskSolution.ID, by user: User) throws -> EventLoopFuture<Void> {

            TaskSolution
                .find(solutionID, on: conn)
                .unwrap(or: Abort(.badRequest))
                .flatMap { (solution: TaskSolution) in

                    try self.userRepository
                        .isModerator(user: user, taskID: solution.taskID)
                        .flatMap {

                            try solution.approve(by: user)
                                .save(on: self.conn)
                    }
            }
            .transform(to: ())
        }

        /// Should be in `TaskSolutionRepositoring`
        public func unverifiedSolutions(in subjectID: Subject.ID, for moderator: User) throws -> EventLoopFuture<[TaskSolution.Unverified]> {

            return try userRepository
                .isModerator(user: moderator, subjectID: subjectID)
                .flatMap {

                    Task.query(on: self.conn)
                        .join(\TaskSolution.taskID, to: \Task.id)
                        .join(\Subtopic.id, to: \Task.subtopicID)
                        .join(\Topic.id, to: \Subtopic.topicId)
                        .filter(\Topic.subjectId == subjectID)
                        .filter(\TaskSolution.approvedBy == nil)
                        .range(0..<10)
                        .alsoDecode(TaskSolution.self)
                        .all()
                        .flatMap { tasks in

                            MultipleChoiseTaskChoise.query(on: self.conn)
                                .filter(\MultipleChoiseTaskChoise.taskId ~~ tasks.map { $0.1.taskID })
                                .all()
                                .map { (choises: [MultipleChoiseTaskChoise]) in

                                    let groupedChoises = choises.group(by: \.taskId)

                                    return tasks.map { task, solution in
                                        TaskSolution.Unverified(
                                            task: task,
                                            solution: solution,
                                            choises: groupedChoises[solution.taskID] ?? []
                                        )
                                    }
                            }
                    }
            }
            .catchMap { _ in [] }
        }
    }
}
