
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

    public struct HighOverview: Content {

        public let id: TaskSession.ID
        public let createdAt: Date
        public let subjectName: String
        public let subjectID: Subject.ID
        public let testTitle: String
    }
}
