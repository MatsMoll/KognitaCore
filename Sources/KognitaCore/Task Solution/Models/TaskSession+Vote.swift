import Vapor
import FluentKit

extension TaskSolution {
    enum Pivot {
        final class Vote: Model {

            public static var schema: String = "TaskSolution.Vote"

            @DBID(custom: "id")
            var id: Int?

            @Parent(key: "userID")
            var user: User.DatabaseModel

            @Parent(key: "solutionID")
            var solution: TaskSolution.DatabaseModel

            init(userID: User.ID, solutionID: TaskSolution.ID) {
                self.$user.id = userID
                self.$solution.id = solutionID
            }

            init() {}
        }
    }
}

//extension TaskSolution.Pivot.Vote: PostgreSQLMigration {
//
//    static func prepare(on connection: PostgreSQLConnection) -> EventLoopFuture<Void> {
//        PostgreSQLDatabase.create(TaskSolution.Pivot.Vote.self, on: connection) { (builder) in
//            try addProperties(to: builder)
//
//            builder.reference(from: \.userID, to: \User.DatabaseModel.id, onUpdate: .cascade, onDelete: .cascade)
//            builder.reference(from: \.solutionID, to: \TaskSolution.DatabaseModel.id, onUpdate: .cascade, onDelete: .cascade)
//            builder.unique(on: \.solutionID, \.userID)
//        }
//    }
//
//    static func revert(on connection: PostgreSQLConnection) -> EventLoopFuture<Void> {
//        PostgreSQLDatabase.delete(TaskSolution.Pivot.Vote.self, on: connection)
//    }
//}

extension TaskSolution.Pivot.Vote {
    enum Migrations {
        struct Create: KognitaModelMigration {
            typealias Model = TaskSolution.Pivot.Vote

            func build(schema: SchemaBuilder) -> SchemaBuilder {
                schema.field("userID", .uint, .required, .references(User.DatabaseModel.schema, .id, onDelete: .cascade, onUpdate: .cascade))
                    .field("solutionID", .uint, .required, .references(TaskSolution.DatabaseModel.schema, .id, onDelete: .cascade, onUpdate: .cascade))
            }
        }
    }
}
