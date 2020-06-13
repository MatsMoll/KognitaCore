import Foundation
import FluentPostgreSQL
import Vapor

extension TestSession {
    final class DatabaseModel: KognitaPersistenceModel {

        public static var tableName: String = "TestSession"

        public var createdAt: Date?

        public var updatedAt: Date?

        public var id: Int?

        public var submittedAt: Date?

        public var testID: SubjectTest.ID

        public var hasSubmitted: Bool { submittedAt != nil }

        init(sessionID: TaskSession.ID, testID: SubjectTest.ID) {
            self.id = sessionID
            self.testID = testID
        }

        func representable(with session: TaskSession) -> TestSessionRepresentable {
            TestSession.TestParameter(session: session, testSession: self)
        }

        func representable(on conn: DatabaseConnectable) throws -> EventLoopFuture<TestSessionRepresentable> {
            let session = self
            return try TaskSession.find(requireID(), on: conn)
                .unwrap(or: Abort(.internalServerError))
                .map { TestSession.TestParameter(session: $0, testSession: session) }
        }
    }
}

extension TestSession.DatabaseModel: ContentConvertable {
    func content() throws -> TestSession {
        try .init(
            id: requireID(),
            createdAt: createdAt ?? .now,
            submittedAt: submittedAt,
            testID: testID
        )
    }
}

extension TestSession: Content {}

extension TestSession {

    struct TestParameter: Codable, TestSessionRepresentable {

        let session: TaskSession
        let testSession: TestSession.DatabaseModel

        public var userID: User.ID { session.userID }
        public var createdAt: Date? { session.createdAt }
        public var testID: SubjectTest.ID { testSession.testID }
        public var submittedAt: Date? { testSession.submittedAt }
        public var executedAt: Date? { testSession.createdAt }

        public func requireID() throws -> Int { try session.requireID() }

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

        public static func resolveWith(_ id: Int, conn: DatabaseConnectable) -> EventLoopFuture<TestParameter.ParameterModel> {
            return TaskSession.query(on: conn)
                .join(\TestSession.DatabaseModel.id, to: \TaskSession.id)
                .filter(\TaskSession.id == id)
                .alsoDecode(TestSession.DatabaseModel.self)
                .first()
                .unwrap(or: Abort(.internalServerError))
                .map {
                    return TestParameter(session: $0.0, testSession: $0.1)
            }
        }
    }
}
