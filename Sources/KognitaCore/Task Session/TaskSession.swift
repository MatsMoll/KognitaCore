import FluentPostgreSQL
import Vapor

final class TaskSession: PostgreSQLModel, Migration {

    public typealias Database = PostgreSQLDatabase

    public var createdAt: Date?

    public var id: Int?

    public var userID: User.ID

    init(userID: User.ID) {
        self.userID = userID
    }

    public static var createdAtKey: WritableKeyPath<TaskSession, Date?>? = \.createdAt
}

extension TaskSession {

    static func prepare(on conn: PostgreSQLConnection) -> EventLoopFuture<Void> {
        PostgreSQLDatabase.create(TaskSession.self, on: conn) { builder in
            try addProperties(to: builder)
        }.flatMap {
            PostgreSQLDatabase.update(TaskSession.self, on: conn) { builder in
                builder.deleteField(for: \.userID)
                builder.field(for: \.userID, type: .int, .default(1))
                builder.reference(from: \.userID, to: \User.DatabaseModel.id, onUpdate: .cascade, onDelete: .setDefault)
            }
        }
    }

    static func revert(on conn: PostgreSQLConnection) -> EventLoopFuture<Void> {
        PostgreSQLDatabase.delete(TaskSession.self, on: conn)
    }
}

extension PracticeSession {
    public struct PracticeParameter: ModelParameterRepresentable, Content, PracticeSessionRepresentable {

        let session: TaskSession
        let practiceSession: PracticeSession.DatabaseModel

        public var id: Int? { session.id }
        public var userID: User.ID { session.userID }
        public var createdAt: Date? { session.createdAt }
        public var endedAt: Date? { practiceSession.endedAt }
        public var numberOfTaskGoal: Int { practiceSession.numberOfTaskGoal }
        public func requireID() throws -> Int { try session.requireID() }

        public typealias ParameterModel = PracticeParameter
        public typealias ResolvedParameter = EventLoopFuture<PracticeParameter>

        public static func resolveParameter(_ parameter: String, conn: DatabaseConnectable) -> EventLoopFuture<PracticeParameter> {
            guard let id = Int(parameter) else {
                return conn.future(error: Abort(.badRequest, reason: "Was not able to interpret \(parameter) as `Int`."))
            }
            return TaskSession.query(on: conn)
                .join(\PracticeSession.DatabaseModel.id, to: \TaskSession.id)
                .filter(\TaskSession.id == id)
                .alsoDecode(PracticeSession.DatabaseModel.self)
                .first()
                .unwrap(or: Abort(.internalServerError))
                .map {
                    PracticeParameter(session: $0.0, practiceSession: $0.1)
            }
        }
        public static func resolveParameter(_ parameter: String, on container: Container) throws -> EventLoopFuture<PracticeParameter> {
            throw Abort(.notImplemented)
        }

        public func end(on conn: DatabaseConnectable) -> EventLoopFuture<PracticeSessionRepresentable> {
            let session = self.session
            practiceSession.endedAt = .now
            return practiceSession.save(on: conn)
                .map { practiceSession in

                    PracticeSession.PracticeParameter(
                        session: session,
                        practiceSession: practiceSession
                    )
            }
        }

        public func extendSession(with numberOfTasks: Int, on conn: DatabaseConnectable) -> EventLoopFuture<PracticeSessionRepresentable> {
            practiceSession.numberOfTaskGoal += abs(numberOfTasks)
            return practiceSession.save(on: conn)
                .transform(to: self)
        }
    }
}
