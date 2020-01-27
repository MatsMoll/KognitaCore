import Foundation
import FluentPostgreSQL
import Vapor

public final class TestSession: KognitaPersistenceModel {

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


extension TaskSession {

    public struct TestParameter: Parameter, Codable, TestSessionRepresentable {

        let session: TaskSession
        let testSession: TestSession

        public var userID: User.ID              { session.userID }
        public var createdAt: Date?             { session.createdAt }
        public var testID: SubjectTest.ID       { testSession.testID }
        public var submittedAt: Date?           { testSession.submittedAt }

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

extension TestSession {

    public struct Results: Content {

        public struct Task: Content {
            public let question: String
            public let score: Double
        }

        public struct Topic: Content {
            public let name: String
            public let taskResults: [Task]

            public let score: Double
            public let maximumScore: Double

            public var scoreProsentage: Double {
                guard maximumScore != 0 else { return 0 }
                return score / maximumScore
            }

            public var readableScoreProsentage: Double {
                scoreProsentage * 100
            }

            init(name: String, taskResults: [Task]) {
                self.name = name
                self.taskResults = taskResults

                self.score = taskResults.reduce(0) { $0 + $1.score }
                self.maximumScore = Double(taskResults.count)
            }
        }

        public let testTitle: String
        public let executedAt: Date
        public let shouldPresentDetails: Bool
        public let topicResults: [Topic]

        public let score: Double
        public let maximumScore: Double

        public var scoreProsentage: Double {
            guard maximumScore != 0 else { return 0 }
            return score / maximumScore
        }

        init(testTitle: String, executedAt: Date, shouldPresentDetails: Bool, topicResults: [Topic]) {
            self.testTitle = testTitle
            self.executedAt = executedAt
            self.shouldPresentDetails = shouldPresentDetails
            self.topicResults = topicResults
            self.score = topicResults.reduce(0) { $0 + $1.score }
            self.maximumScore = topicResults.reduce(0) { $0 + $1.maximumScore }
        }
    }
}
