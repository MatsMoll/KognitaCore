import Vapor
import FluentSQL

extension TaskSession {

    public struct TestParameter: ModelParameterRepresentable, Codable, TestSessionRepresentable {

        let session: TaskSession
        let testSession: TestSession

        public var userID: User.ID              { session.userID }
        public var createdAt: Date?             { session.createdAt }
        public var testID: SubjectTest.ID       { testSession.testID }
        public var submittedAt: Date?           { testSession.submittedAt }
        public var expectedScore: Int?          { testSession.expectedScore }

        public func requireID() throws -> Int   { try session.requireID() }

        public func submit(on conn: DatabaseConnectable) throws -> EventLoopFuture<TestSessionRepresentable> {
            guard submittedAt == nil else {
                throw Abort(.badRequest)
            }
            testSession.submittedAt = .now
            return testSession.save(on: conn)
                .transform(to: self)
        }


        public typealias ResolvedParameter = EventLoopFuture<TestParameter>
        public typealias ParameterModel = TestParameter

        public static func resolveParameter(_ parameter: String, on container: Container) throws -> EventLoopFuture<TaskSession.TestParameter> {
            throw Abort(.notImplemented)
        }

        public static func resolveParameter(_ parameter: String, conn: DatabaseConnectable) -> EventLoopFuture<TaskSession.TestParameter.ParameterModel> {
            guard let id = Int(parameter) else {
                return conn.future(error: Abort(.badRequest, reason: "Was not able to interpret \(parameter) as `Int`."))
            }
            return TaskSession.query(on: conn)
                .join(\TestSession.id, to: \TaskSession.id)
                .filter(\TaskSession.id == id)
                .alsoDecode(TestSession.self)
                .first()
                .unwrap(or: Abort(.internalServerError))
                .map {
                    return TestParameter(session: $0.0, testSession: $0.1)
            }
        }
    }
}

