import Vapor
import FluentKit

final class TaskSession: Model {

    static var schema: String = "TaskSession"

    @Timestamp(key: "createdAt", on: .create)
    public var createdAt: Date?

    @DBID(custom: "id")
    public var id: Int?

    @Parent(key: "userID")
    public var user: User.DatabaseModel

    init(userID: User.ID) {
        self.$user.id = userID
    }

    init() {}

    @Parent(key: "id")
    var practiceSession: PracticeSession.DatabaseModel
}

extension TaskSession {
    enum Migrations {}
}

extension TaskSession.Migrations {
    struct Create: Migration {

        let schema = TaskSession.schema

        func prepare(on database: Database) -> EventLoopFuture<Void> {
            database.schema(schema)
                .field("id", .uint, .identifier(auto: true))
                .field("createdAt", .datetime, .required)
                .field("userID", .uint, .required, .references(User.DatabaseModel.schema, .id, onDelete: .setDefault, onUpdate: .cascade), .sql(.default(1)))
                .create()
        }

        func revert(on database: Database) -> EventLoopFuture<Void> {
            database.schema(schema).delete()
        }
    }
}

extension PracticeSession {
    public struct PracticeParameter: Content, PracticeSessionRepresentable {

        let session: TaskSession
        let practiceSession: PracticeSession.DatabaseModel

        public var id: Int? { session.id }
        public var userID: User.ID { session.$user.id }
        public var createdAt: Date? { session.createdAt }
        public var endedAt: Date? { practiceSession.endedAt }
        public var numberOfTaskGoal: Int { practiceSession.numberOfTaskGoal }
        public func requireID() throws -> Int { try session.requireID() }

        public typealias ParameterModel = PracticeParameter
        public typealias ResolvedParameter = EventLoopFuture<PracticeParameter>

        public func content() -> PracticeSession {
            PracticeSession(model: practiceSession)
        }

        public static func resolveWith(_ id: Int, database: Database) -> EventLoopFuture<PracticeSessionRepresentable> {
            return TaskSession.query(on: database)
                .join(PracticeSession.DatabaseModel.self, on: \PracticeSession.DatabaseModel.$id == \TaskSession.$id)
                .filter(\TaskSession.$id == id)
                .limit(1)
                .all(with: \.$practiceSession)
                .flatMapThrowing { sessions in
                    guard let first = sessions.first else { throw Abort(.internalServerError) }
                    return PracticeParameter(session: first, practiceSession: first.practiceSession)
            }
        }

        public func end(on database: Database) -> EventLoopFuture<PracticeSessionRepresentable> {
            let session = self.session
            practiceSession.endedAt = .now
            return practiceSession.save(on: database)
                .map {
                    PracticeSession.PracticeParameter(
                        session: session,
                        practiceSession: self.practiceSession
                    )
            }
        }

        public func extendSession(with numberOfTasks: Int, on database: Database) -> EventLoopFuture<PracticeSessionRepresentable> {
            practiceSession.numberOfTaskGoal += abs(numberOfTasks)
            return practiceSession.save(on: database)
                .transform(to: self)
        }
    }
}
