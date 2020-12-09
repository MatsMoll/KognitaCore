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

        public init(database: Database, userRepository: UserRepository) {
            self.database = database
            self.userRepository = userRepository
        }

        typealias DatabaseModel = TaskSolution

        public let database: Database
        private var userRepository: UserRepository

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
                .join(parent: \TaskSolution.DatabaseModel.$creator)
                .with(\.$approvedBy)
                .filter(\.$task.$id == taskID)
                .all(with: \.$creator)
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
        
        public func solutionsFor(subjectID: Subject.ID) -> EventLoopFuture<[TaskSolution]> {
            TaskSolution.DatabaseModel.query(on: database)
                .join(parent: \TaskSolution.DatabaseModel.$task)
                .join(parent: \TaskDatabaseModel.$subtopic)
                .join(parent: \Subtopic.DatabaseModel.$topic)
                .filter(Topic.DatabaseModel.self, \Topic.DatabaseModel.$subject.$id == subjectID)
                .all()
                .flatMapEachThrowing { (solution: TaskSolution.DatabaseModel) in
                    try solution.content()
                }
        }

        public func upvote(for solutionID: TaskSolution.ID, by user: User) throws -> EventLoopFuture<Void> {
            TaskSolution.Pivot.Vote(userID: user.id, solutionID: solutionID)
                .create(on: database)
        }

        public func revokeVote(for solutionID: TaskSolution.ID, by user: User) throws -> EventLoopFuture<Void> {
            TaskSolution.Pivot.Vote.query(on: database)
                .filter(\.$user.$id == user.id)
                .filter(\.$solution.$id == solutionID)
                .first()
                .unwrap(or: Abort(.badRequest))
                .delete(on: database)
        }

        public func updateModelWith(id: Int, to data: TaskSolution.Update.Data, by user: User) throws -> EventLoopFuture<TaskSolution> {
            TaskSolution.DatabaseModel.find(id, on: database)
                .unwrap(or: Abort(.badRequest))
                .failableFlatMap { solution in
                    try self.update(model: solution, to: data, by: user)
            }
        }

        func update(model: TaskSolution.DatabaseModel, to data: TaskSolution.Update.Data, by user: User) throws -> EventLoopFuture<TaskSolution> {
            if model.$creator.id == user.id {
                try model.update(with: data)
                return model.save(on: database)
                    .flatMapThrowing { try model.content() }
            } else {
                return self.userRepository
                    .isModerator(user: user, taskID: model.$task.id)
                    .ifFalse(throw: Abort(.forbidden))
                    .failableFlatMap {
                        try model.update(with: data)
                        return model.save(on: self.database)
                            .flatMapThrowing { try model.content() }
                }
            }
        }

        public func deleteModelWith(id: Int, by user: User?) throws -> EventLoopFuture<Void> {
            guard let user = user else {
                throw Abort(.unauthorized)
            }

            return TaskSolution.DatabaseModel.find(id, on: database)
                .unwrap(or: Abort(.badRequest))
                .flatMap { solution in

                    TaskSolution.DatabaseModel.query(on: self.database)
                        .filter(\.$task.$id == solution.$task.id)
                        .count()
                        .failableFlatMap { numberOfSolutions in

                            guard numberOfSolutions > 1 else { throw TaskSolutionRepositoryError.toFewSolutions }

                            if solution.$creator.id == user.id {
                                return solution.delete(on: self.database)
                            } else {
                                return self.userRepository.isModerator(user: user, taskID: solution.$task.id)
                                    .ifFalse(throw: Abort(.forbidden))
                                    .flatMap {
                                        solution.delete(on: self.database)
                                }
                            }
                    }
            }
        }

        public func approve(for solutionID: TaskSolution.ID, by user: User) throws -> EventLoopFuture<Void> {

            TaskSolution.DatabaseModel
                .find(solutionID, on: database)
                .unwrap(or: Abort(.badRequest))
                .flatMap { (solution: TaskSolution.DatabaseModel) in

                    self.userRepository
                        .isModerator(user: user, taskID: solution.$task.id)
                        .ifFalse(throw: Abort(.forbidden))
                        .flatMap {
                            solution.approve(by: user)
                                .save(on: self.database)
                    }
            }
        }

        /// Should be in `TaskSolutionRepositoring`
        public func unverifiedSolutions(in subjectID: Subject.ID, for moderator: User) throws -> EventLoopFuture<[TaskSolution.Unverified]> {

            return userRepository
                .isModerator(user: moderator, subjectID: subjectID)
                .ifFalse(throw: Abort(.forbidden))
                .flatMap {

                    TaskSolution.DatabaseModel.query(on: self.database)
                        .join(parent: \TaskSolution.DatabaseModel.$task)
                        .join(parent: \TaskDatabaseModel.$subtopic)
                        .join(parent: \Subtopic.DatabaseModel.$topic)
                        .filter(Topic.DatabaseModel.self, \Topic.DatabaseModel.$subject.$id == subjectID)
                        .filter(\TaskSolution.DatabaseModel.$isApproved == false)
                        .range(0..<10)
                        .all(with: \.$task)
                        .flatMap { tasks in

                            MultipleChoiseTaskChoise.query(on: self.database)
                                .filter(\MultipleChoiseTaskChoise.$task.$id ~~ tasks.map { $0.$task.id })
                                .all()
                                .flatMapThrowing { (choises: [MultipleChoiseTaskChoise]) in

                                    let groupedChoises = choises.group(by: \.$task.id)

                                    return try tasks.map { solution in
                                        try TaskSolution.Unverified(
                                            task: solution.task,
                                            solution: solution.content(),
                                            choises: groupedChoises[solution.$task.id] ?? []
                                        )
                                    }
                            }
                    }
            }
            .flatMapError { _ in self.database.eventLoop.future([]) }
        }
    }
}
