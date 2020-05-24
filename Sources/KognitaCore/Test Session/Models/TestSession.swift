import Foundation
import FluentPostgreSQL
import Vapor

public final class TestSession: KognitaPersistenceModel {

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

    public struct TestParameter: ModelParameterRepresentable, Codable, TestSessionRepresentable {

        let session: TaskSession
        let testSession: TestSession

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

extension TestSession {

    public struct Results: Content {

        public struct Task: Content {
            public let pivotID: SubjectTest.Pivot.Task.ID
            public let question: String
            public let score: Double
        }

        public struct Topic: Content {
            public let id: KognitaCore.Topic.ID
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

            init(id: KognitaCore.Topic.ID, name: String, taskResults: [Task]) {
                self.id = id
                self.name = name
                self.taskResults = taskResults

                self.score = taskResults.reduce(0) { $0 + $1.score }
                self.maximumScore = Double(taskResults.count)
            }
        }

        public let testTitle: String
        public let testIsOpen: Bool
        public let executedAt: Date
        public let endedAt: Date
        public let shouldPresentDetails: Bool
        public let topicResults: [Topic]
        public let subjectID: Subject.ID
        public let canPractice: Bool

        public let score: Double
        public let maximumScore: Double

        public var scoreProsentage: Double {
            guard maximumScore != 0 else { return 0 }
            return score / maximumScore
        }

        init(testTitle: String, endedAt: Date, testIsOpen: Bool, executedAt: Date, shouldPresentDetails: Bool, subjectID: Subject.ID, canPractice: Bool, topicResults: [Topic]) {
            self.testTitle = testTitle
            self.testIsOpen = testIsOpen
            self.executedAt = executedAt
            self.endedAt = endedAt
            self.shouldPresentDetails = shouldPresentDetails
            self.subjectID = subjectID
            self.canPractice = canPractice
            self.topicResults = topicResults
            self.score = topicResults.reduce(0) { $0 + $1.score }
            self.maximumScore = topicResults.reduce(0) { $0 + $1.maximumScore }
        }
    }
}
