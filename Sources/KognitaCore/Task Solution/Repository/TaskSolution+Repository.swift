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

        typealias DatabaseModel = TaskSolution

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

        public func create(from content: TaskSolution.Create.Data, by user: User?) throws -> EventLoopFuture<TaskSolution> {

            guard let user = user else { throw Abort(.unauthorized) }

            return try TaskSolution.DatabaseModel(
                data: TaskSolution.Create.Data(
                    solution: content.solution,
                    presentUser: true,
                    taskID: content.taskID
                ),
                creatorID: user.id
            )
            .save(on: conn)
            .flatMap { solution in

                try self
                    .userRepository
                    .isModerator(user: user, taskID: content.taskID)
                    .flatMap(to: Void.self) {
                        solution.isApproved = true
                        solution.approvedBy = user.id
                        return solution.save(on: self.conn)
                            .transform(to: ())
                }
                .catchMap { _ in () }
                .map { _ in try solution.content() }
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
                            .join(\TaskSolution.Pivot.Vote.solutionID, to: \TaskSolution.DatabaseModel.id)
                            .where(\TaskSolution.DatabaseModel.taskID == taskID)
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
            TaskSolution.Pivot.Vote(userID: user.id, solutionID: solutionID)
                .create(on: conn)
                .transform(to: ())
        }

        public func revokeVote(for solutionID: TaskSolution.ID, by user: User) throws -> EventLoopFuture<Void> {
            TaskSolution.Pivot.Vote.query(on: conn)
                .filter(\.userID == user.id)
                .filter(\.solutionID == solutionID)
                .first()
                .unwrap(or: Abort(.badRequest))
                .flatMap { vote in
                    vote.delete(on: self.conn)
            }
        }

        public func update(model: TaskSolution, to data: TaskSolution.Update.Data, by user: User) throws -> EventLoopFuture<TaskSolution> {
            if model.creatorID == user.id {
                return TaskSolution.DatabaseModel
                    .find(model.id, on: conn)
                    .unwrap(or: Abort(.badRequest))
                    .flatMap { model in
                        try model.update(with: data)
                        return model.save(on: self.conn)
                            .map { try $0.content() }
                }
            } else {
                return try self.userRepository.isModerator(user: user, taskID: model.taskID).flatMap {
                    TaskSolution.DatabaseModel
                        .find(model.id, on: self.conn)
                        .unwrap(or: Abort(.badRequest))
                        .flatMap { model in
                            try model.update(with: data)
                            return model.save(on: self.conn)
                                .map { try $0.content() }
                    }
                }
            }
        }

        public func delete(model: TaskSolution, by user: User?) throws -> EventLoopFuture<Void> {
            guard let user = user else {
                throw Abort(.unauthorized)
            }

            return TaskSolution.DatabaseModel.query(on: conn)
                .filter(\.taskID == model.taskID)
                .count()
                .flatMap { numberOfSolutions in

                    guard numberOfSolutions > 1 else { throw TaskSolutionRepositoryError.toFewSolutions }

                    return TaskSolution.DatabaseModel
                        .find(model.id, on: self.conn)
                        .unwrap(or: Abort(.badRequest))
                        .flatMap { model in
                            if model.creatorID == user.id {
                                return model.delete(on: self.conn)
                            } else {
                                return try self.userRepository.isModerator(user: user, taskID: model.taskID).flatMap {
                                    model.delete(on: self.conn)
                                }
                            }
                    }
            }
        }

        public func approve(for solutionID: TaskSolution.ID, by user: User) throws -> EventLoopFuture<Void> {

            TaskSolution.DatabaseModel
                .find(solutionID, on: conn)
                .unwrap(or: Abort(.badRequest))
                .flatMap { (solution: TaskSolution.DatabaseModel) in

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
                        .join(\TaskSolution.DatabaseModel.taskID, to: \Task.id)
                        .join(\Subtopic.DatabaseModel.id, to: \Task.subtopicID)
                        .join(\Topic.DatabaseModel.id, to: \Subtopic.DatabaseModel.topicID)
                        .filter(\Topic.DatabaseModel.subjectId == subjectID)
                        .filter(\TaskSolution.DatabaseModel.approvedBy == nil)
                        .range(0..<10)
                        .alsoDecode(TaskSolution.DatabaseModel.self)
                        .all()
                        .flatMap { tasks in

                            MultipleChoiseTaskChoise.query(on: self.conn)
                                .filter(\MultipleChoiseTaskChoise.taskId ~~ tasks.map { $0.1.taskID })
                                .all()
                                .map { (choises: [MultipleChoiseTaskChoise]) in

                                    let groupedChoises = choises.group(by: \.taskId)

                                    return try tasks.map { task, solution in
                                        try TaskSolution.Unverified(
                                            task: task,
                                            solution: solution.content(),
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
