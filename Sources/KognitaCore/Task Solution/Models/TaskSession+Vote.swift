import Vapor
import FluentPostgreSQL

extension TaskSolution {
    public enum Pivot {
        final class Vote: PostgreSQLModel {

            public static var entity: String = "TaskSolution.Pivot.Vote"
            public static var name: String = "TaskSolution.Pivot.Vote"

            var id: Int?

            let userID: User.ID
            let solutionID: TaskSolution.ID

            init(userID: User.ID, solutionID: TaskSolution.ID) {
                self.userID = userID
                self.solutionID = solutionID
            }
        }
    }
}

extension TaskSolution.Pivot.Vote: PostgreSQLMigration {

    static func prepare(on connection: PostgreSQLConnection) -> EventLoopFuture<Void> {
        PostgreSQLDatabase.create(TaskSolution.Pivot.Vote.self, on: connection) { (builder) in
            try addProperties(to: builder)

            builder.reference(from: \.userID, to: \User.DatabaseModel.id, onUpdate: .cascade, onDelete: .cascade)
            builder.reference(from: \.solutionID, to: \TaskSolution.DatabaseModel.id, onUpdate: .cascade, onDelete: .cascade)
            builder.unique(on: \.solutionID, \.userID)
        }
    }

    static func revert(on connection: PostgreSQLConnection) -> EventLoopFuture<Void> {
        PostgreSQLDatabase.delete(TaskSolution.Pivot.Vote.self, on: connection)
    }
}
