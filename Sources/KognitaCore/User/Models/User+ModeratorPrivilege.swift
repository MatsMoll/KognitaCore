import FluentPostgreSQL

extension User {
    final class ModeratorPrivilege: KognitaPersistenceModel {

        public static var tableName: String = "User.ModeratorPrivilege"

        public var createdAt: Date?
        public var updatedAt: Date?
        public var id: Int?

        let userID: User.ID
        let subjectID: Subject.ID

        init(userID: User.ID, subjectID: Subject.ID) {
            self.userID = userID
            self.subjectID = subjectID
        }
    }
}

extension User.ModeratorPrivilege {

    public static func prepare(on conn: PostgreSQLConnection) -> EventLoopFuture<Void> {
        PostgreSQLDatabase.create(User.ModeratorPrivilege.self, on: conn) { builder in
            try addProperties(to: builder)
            builder.reference(from: \.userID, to: \User.DatabaseModel.id, onUpdate: .cascade, onDelete: .cascade)
            builder.reference(from: \.subjectID, to: \Subject.DatabaseModel.id, onUpdate: .cascade, onDelete: .cascade)
            builder.unique(on: \.subjectID, \.userID)
        }
    }
}
