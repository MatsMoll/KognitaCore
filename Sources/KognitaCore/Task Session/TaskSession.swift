import FluentPostgreSQL
import Vapor

public final class TaskSession: PostgreSQLModel, Migration {

    public var createdAt: Date?

    public var id: Int?

    public var userID: User.ID

    init(userID: User.ID) {
        self.userID = userID
    }

    public static var createdAtKey: WritableKeyPath<TaskSession, Date?>? = \.createdAt
}


extension TaskSession {

    public static func prepare(on conn: PostgreSQLConnection) -> EventLoopFuture<Void> {
        PostgreSQLDatabase.create(TaskSession.self, on: conn) { builder in
            try addProperties(to: builder)
        }.flatMap {
            PostgreSQLDatabase.update(TaskSession.self, on: conn) { builder in
                builder.deleteField(for: \.userID)
                builder.field(for: \.userID, type: .int, .default(1))
                builder.reference(from: \.userID, to: \User.id, onUpdate: .cascade, onDelete: .setDefault)
            }
        }
    }

    public static func revert(on conn: PostgreSQLConnection) -> EventLoopFuture<Void> {
        PostgreSQLDatabase.delete(TaskSession.self, on: conn)
    }
}



extension TaskSession {
    public struct PracticeParameter: Parameter, Codable, PracticeSessionRepresentable {

        let session: TaskSession
        let practiceSession: PracticeSession

        public var userID: User.ID              { session.userID }
        public var createdAt: Date?             { session.createdAt }
        public var numberOfTaskGoal: Int        { practiceSession.numberOfTaskGoal }
        public func requireID() throws -> Int   { try session.requireID() }

        public typealias ResolvedParameter = EventLoopFuture<PracticeParameter>

        public static func resolveParameter(_ parameter: String, on container: Container) throws -> EventLoopFuture<TaskSession.PracticeParameter> {
            guard let id = Int(parameter) else {
                throw Abort(.badRequest, reason: "Was not able to interpret \(parameter) as `Int`.")
            }
            return container.requestCachedConnection(to: .psql)
                .flatMap { conn in
                    
                    TaskSession.query(on: conn)
                        .join(\PracticeSession.id, to: \TaskSession.id)
                        .filter(\TaskSession.id == id)
                        .alsoDecode(PracticeSession.self)
                        .first()
                        .unwrap(or: Abort(.internalServerError))
                        .map {
                            PracticeParameter(session: $0.0, practiceSession: $0.1)
                    }
            }
        }
    }
}
