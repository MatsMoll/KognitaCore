import Vapor
import FluentKit

extension User {
    final class ModeratorPrivilege: KognitaPersistenceModel {

        public static var tableName: String = "User.ModeratorPrivilege"

        @Timestamp(key: "createdAt", on: .create)
        public var createdAt: Date?

        @Timestamp(key: "updatedAt", on: .update)
        public var updatedAt: Date?

        @DBID(custom: "id")
        public var id: Int?

        @Parent(key: "userID")
        var user: User.DatabaseModel

        @Parent(key: "subjectID")
        var subject: Subject.DatabaseModel

        init(userID: User.ID, subjectID: Subject.ID) {
            self.$user.id = userID
            self.$subject.id = subjectID
        }

        init() {}
    }
}

extension User.ModeratorPrivilege {
    enum Migrations {}
}
extension User.ModeratorPrivilege.Migrations {
    struct Create: KognitaModelMigration {
        typealias Model = User.ModeratorPrivilege

        func build(schema: SchemaBuilder) -> SchemaBuilder {
            schema.field("userID", .uint, .required, .references(User.DatabaseModel.schema, .id, onDelete: .cascade, onUpdate: .cascade))
                .field("subjectID", .uint, .required, .references(Subject.DatabaseModel.schema, .id, onDelete: .cascade, onUpdate: .cascade))
                .defaultTimestamps()
                .unique(on: "subjectID", "userID")
        }
    }
}
//extension User.ModeratorPrivilege {
//
//    public static func prepare(on conn: PostgreSQLConnection) -> EventLoopFuture<Void> {
//        PostgreSQLDatabase.create(User.ModeratorPrivilege.self, on: conn) { builder in
//            try addProperties(to: builder)
//            builder.reference(from: \.userID, to: \User.DatabaseModel.id, onUpdate: .cascade, onDelete: .cascade)
//            builder.reference(from: \.subjectID, to: \Subject.DatabaseModel.id, onUpdate: .cascade, onDelete: .cascade)
//            builder.unique(on: \.subjectID, \.userID)
//        }
//    }
//}
