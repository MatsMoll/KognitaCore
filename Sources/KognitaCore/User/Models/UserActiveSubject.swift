import Vapor
import FluentPostgreSQL

extension User {
    public final class ActiveSubject: KognitaPersistenceModel {

        public static var entity: String = "User.ActiveSubject"
        public static var name: String = "User.ActiveSubject"

        public var createdAt: Date?
        public var updatedAt: Date?
        public var id: Int?

        let userID: User.ID
        let subjectID: Subject.ID
        public var canPractice: Bool

        init(userID: User.ID, subjectID: Subject.ID, canPractice: Bool) {
            self.userID = userID
            self.subjectID = subjectID
            self.canPractice = canPractice
        }
    }
}

extension User.ActiveSubject {

    public static func prepare(on conn: PostgreSQLConnection) -> EventLoopFuture<Void> {
        PostgreSQLDatabase.create(User.ActiveSubject.self, on: conn) { builder in
            try addProperties(to: builder)
            builder.reference(from: \.userID, to: \User.id, onUpdate: .cascade, onDelete: .cascade)
            builder.reference(from: \.subjectID, to: \Subject.id, onUpdate: .cascade, onDelete: .cascade)
            builder.unique(on: \.subjectID, \.userID)
        }
    }
}

