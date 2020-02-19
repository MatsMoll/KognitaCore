import Foundation
import FluentPostgreSQL
import Vapor

public final class TestSession: KognitaPersistenceModel {

    public var createdAt: Date?

    public var updatedAt: Date?

    public var id: Int?

    public var submittedAt: Date?

    public var testID: SubjectTest.ID

    /// Expected score of a user for a given test (0..100) 
    public var expectedScore: Int?

    public var hasSubmitted: Bool { submittedAt != nil }

    init(sessionID: TaskSession.ID, testID: SubjectTest.ID, expectedScore: Int?) {
        self.id = sessionID
        self.testID = testID
        self.expectedScore = expectedScore?.clamped(to: 0...100)
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

extension TestSession: Content {}
