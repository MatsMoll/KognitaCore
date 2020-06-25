import Vapor
import FluentKit
import Fluent

enum TaskSolutionRepositoryError: String, Error {

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

        public init(database: Database) {
            self.database = database
        }

        typealias DatabaseModel = TaskSolution

        public let database: Database
        private var userRepository: some UserRepository { User.DatabaseRepository(database: database) }

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

            let solution = try TaskSolution.DatabaseModel(
                data: TaskSolution.Create.Data(
                    solution: content.solution,
                    presentUser: true,
                    taskID: content.taskID
                ),
                creatorID: user.id
            )

            return solution.save(on: database)
                .failableFlatMap {

                    try self
                        .userRepository
                        .isModerator(user: user, taskID: content.taskID)
                        .flatMap { isModerator in
                            guard isModerator else { return self.database.eventLoop.future() }
                            solution.isApproved = true
                            solution.$approvedBy.id = user.id
                            return solution.save(on: self.database)
                    }
                }
                .flatMapThrowing { try solution.content() }
        }

        public func solutions(for taskID: Task.ID, for user: User) -> EventLoopFuture<[TaskSolution.Response]> {

            return TaskSolution.DatabaseModel.query(on: database)
                .with(\.$approvedBy)
                .with(\.$creator)
                .all()
                .flatMap { solutions in

                    TaskSolution.Pivot.Vote.query(on: self.database)
                        .join(parent: \TaskSolution.Pivot.Vote.$solution)
                        .filter(TaskSolution.DatabaseModel.self, \TaskSolution.DatabaseModel.$task.$id == taskID)
                        .all()
                        .map { votes in

                            let counts = votes.count(equal: \.$solution.id)

                            return solutions.map { solution in
                                return TaskSolution.Response(
                                    solution: solution,
                                    numberOfVotes: counts[solution.id ?? 0] ?? 0,
                                    userHasVoted: votes.contains(where: { vote in vote.$user.id == user.id && vote.$solution.id == solution.id })
                                )
                            }
                            .sorted(by: { first, second in first.numberOfVotes > second.numberOfVotes })
                    }
            }
        }

        public func upvote(for solutionID: TaskSolution.ID, by user: User) throws -> EventLoopFuture<Void> {
            TaskSolution.Pivot.Vote(userID: user.id, solutionID: solutionID)
                .create(on: database)
        }

        public func revokeVote(for solutionID: TaskSolution.ID, by user: User) throws -> EventLoopFuture<Void> {
            return database.eventLoop.future(error: Abort(.notImplemented))
//            TaskSolution.Pivot.Vote.query(on: database)
//                .filter(\.userID == user.id)
//                .filter(\.solutionID == solutionID)
//                .first()
//                .unwrap(or: Abort(.badRequest))
//                .flatMap { vote in
//                    vote.delete(on: self.conn)
//            }
        }

        public func updateModelWith(id: Int, to data: TaskSolution.Update.Data, by user: User) throws -> EventLoopFuture<TaskSolution> {
            return database.eventLoop.future(error: Abort(.notImplemented))
//            TaskSolution.DatabaseModel.find(id, on: conn)
//                .unwrap(or: Abort(.badRequest))
//                .flatMap { solution in
//                    try self.update(model: solution, to: data, by: user)
//            }
        }

        func update(model: TaskSolution.DatabaseModel, to data: TaskSolution.Update.Data, by user: User) throws -> EventLoopFuture<TaskSolution> {
            return database.eventLoop.future(error: Abort(.notImplemented))
//            if model.creatorID == user.id {
//                try model.update(with: data)
//                return model.save(on: self.conn)
//                    .map { try $0.content() }
//            } else {
//                return try self.userRepository.isModerator(user: user, taskID: model.taskID).flatMap {
//                    try model.update(with: data)
//                    return model.save(on: self.conn)
//                        .map { try $0.content() }
//                }
//            }
        }

        public func deleteModelWith(id: Int, by user: User?) throws -> EventLoopFuture<Void> {
            guard let user = user else {
                throw Abort(.unauthorized)
            }

            return database.eventLoop.future(error: Abort(.notImplemented))
//            return TaskSolution.DatabaseModel.find(id, on: conn)
//                .unwrap(or: Abort(.badRequest))
//                .flatMap { solution in
//
//                    TaskSolution.DatabaseModel.query(on: self.conn)
//                        .filter(\.taskID == solution.taskID)
//                        .count()
//                        .flatMap { numberOfSolutions in
//
//                            guard numberOfSolutions > 1 else { throw TaskSolutionRepositoryError.toFewSolutions }
//
//                            if solution.creatorID == user.id {
//                                return solution.delete(on: self.conn)
//                            } else {
//                                return try self.userRepository.isModerator(user: user, taskID: solution.taskID).flatMap {
//                                    solution.delete(on: self.conn)
//                                }
//                            }
//                    }
//            }
        }

        public func approve(for solutionID: TaskSolution.ID, by user: User) throws -> EventLoopFuture<Void> {

            return database.eventLoop.future(error: Abort(.notImplemented))
//            TaskSolution.DatabaseModel
//                .find(solutionID, on: conn)
//                .unwrap(or: Abort(.badRequest))
//                .flatMap { (solution: TaskSolution.DatabaseModel) in
//
//                    try self.userRepository
//                        .isModerator(user: user, taskID: solution.taskID)
//                        .flatMap {
//
//                            try solution.approve(by: user)
//                                .save(on: self.conn)
//                    }
//            }
//            .transform(to: ())
        }

        /// Should be in `TaskSolutionRepositoring`
        public func unverifiedSolutions(in subjectID: Subject.ID, for moderator: User) throws -> EventLoopFuture<[TaskSolution.Unverified]> {

            return database.eventLoop.future(error: Abort(.notImplemented))
//            return try userRepository
//                .isModerator(user: moderator, subjectID: subjectID)
//                .flatMap {
//
//                    TaskDatabaseModel.query(on: self.conn)
//                        .join(\TaskSolution.DatabaseModel.taskID, to: \TaskDatabaseModel.id)
//                        .join(\Subtopic.DatabaseModel.id, to: \TaskDatabaseModel.subtopicID)
//                        .join(\Topic.DatabaseModel.id, to: \Subtopic.DatabaseModel.topicID)
//                        .filter(\Topic.DatabaseModel.subjectId == subjectID)
//                        .filter(\TaskSolution.DatabaseModel.approvedBy == nil)
//                        .range(0..<10)
//                        .alsoDecode(TaskSolution.DatabaseModel.self)
//                        .all()
//                        .flatMap { tasks in
//
//                            MultipleChoiseTaskChoise.query(on: self.conn)
//                                .filter(\MultipleChoiseTaskChoise.taskId ~~ tasks.map { $0.1.taskID })
//                                .all()
//                                .map { (choises: [MultipleChoiseTaskChoise]) in
//
//                                    let groupedChoises = choises.group(by: \.taskId)
//
//                                    return try tasks.map { task, solution in
//                                        try TaskSolution.Unverified(
//                                            task: task,
//                                            solution: solution.content(),
//                                            choises: groupedChoises[solution.taskID] ?? []
//                                        )
//                                    }
//                            }
//                    }
//            }
//            .catchMap { _ in [] }
        }
    }
}
