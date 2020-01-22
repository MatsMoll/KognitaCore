
import Vapor

extension TestSession {
    public struct Overview: Content {

        public let sessionID: TestSession.ID
        public let test: SubjectTest
        public let tasks: [Task]

        public struct Task: Content {
            public let testTaskID: SubjectTest.Pivot.Task.ID
            public let question: String
            public let isAnswered: Bool
        }
    }
}
