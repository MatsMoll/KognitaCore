import Vapor
import FluentKit

extension User {
    public final class ActiveSubject: KognitaPersistenceModel {

        public static var tableName: String = "User.ActiveSubject"

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

        public var subjectID: Subject.ID { $subject.id }

        @Field(key: "canPractice")
        public var canPractice: Bool

        public init() {}

        init(userID: User.ID, subjectID: Subject.ID, canPractice: Bool) {
            self.$user.id = userID
            self.$subject.id = subjectID
            self.canPractice = canPractice
        }
    }
}

extension User.ActiveSubject {
    enum Migrations {
        struct Create: KognitaModelMigration {
            typealias Model = User.ActiveSubject

            func build(schema: SchemaBuilder) -> SchemaBuilder {
                schema.field("canPractice", .bool, .required)
                    .field("userID", .uint, .required, .references(User.DatabaseModel.schema, .id, onDelete: .cascade, onUpdate: .cascade))
                    .field("subjectID", .uint, .required, .references(Subject.DatabaseModel.schema, .id, onDelete: .cascade, onUpdate: .cascade))
                    .defaultTimestamps()
                    .unique(on: "subjectID", "userID")
            }
        }
    }

//    public static func prepare(on conn: PostgreSQLConnection) -> EventLoopFuture<Void> {
//        PostgreSQLDatabase.create(User.ActiveSubject.self, on: conn) { builder in
//            try addProperties(to: builder)
//            builder.reference(from: \.userID, to: \User.DatabaseModel.id, onUpdate: .cascade, onDelete: .cascade)
//            builder.reference(from: \.subjectID, to: \Subject.DatabaseModel.id, onUpdate: .cascade, onDelete: .cascade)
//            builder.unique(on: \.subjectID, \.userID)
//        }
//    }
}
