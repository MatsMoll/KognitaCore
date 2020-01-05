import Foundation
import FluentPostgreSQL
import Vapor

public final class TestSession: KognitaPersistenceModel {

    public var createdAt: Date?

    public var updatedAt: Date?

    public var id: Int?

    public var submittedAt: Date?

    public var testID: SubjectTest.ID

    init(sessionID: TaskSession.ID, testID: SubjectTest.ID) {
        self.id = sessionID
        self.testID = testID
    }

    func representable(with session: TaskSession) -> TestSessionRepresentable {
        TaskSession.TestParameter(session: session, testSession: self)
    }

    func representable(on conn: DatabaseConnectable) throws -> EventLoopFuture<TestSessionRepresentable> {
        let session = self
        return try TaskSession.find(requireID(), on: conn)
            .unwrap(or: Abort(.internalServerError))
            .map { TaskSession.TestParameter(session: $0, testSession: session) }
    }
}


extension TaskSession {

    public struct TestParameter: Parameter, Codable, TestSessionRepresentable {

        let session: TaskSession
        let testSession: TestSession

        public var userID: User.ID              { session.userID }
        public var createdAt: Date?             { session.createdAt }
        public var testID: SubjectTest.ID       { testSession.testID }
        public var submittedAt: Date?           { testSession.submittedAt }

        public func requireID() throws -> Int   { try session.requireID() }


        public typealias ResolvedParameter = EventLoopFuture<TestParameter>

        public static func resolveParameter(_ parameter: String, on container: Container) throws -> EventLoopFuture<TaskSession.TestParameter> {
            guard let id = Int(parameter) else {
                throw Abort(.badRequest, reason: "Was not able to interpret \(parameter) as `Int`.")
            }
            return container.requestCachedConnection(to: .psql)
                .flatMap { conn in

                    TaskSession.query(on: conn)
                        .join(\TestSession.id, to: \TaskSession.id)
                        .filter(\TaskSession.id == id)
                        .alsoDecode(TestSession.self)
                        .first()
                        .unwrap(or: Abort(.internalServerError))
                        .map {
                            TestParameter(session: $0.0, testSession: $0.1)
                    }
            }
        }
    }
}
