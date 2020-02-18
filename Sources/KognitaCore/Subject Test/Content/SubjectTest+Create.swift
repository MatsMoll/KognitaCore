import Vapor

extension SubjectTest {
    public enum Create {
        public struct Data: Content {
            let tasks: [Task.ID]
            let subjectID: Subject.ID
            let duration: TimeInterval
            let scheduledAt: Date
            let password: String
            let title: String
            let isTeamBasedLearning: Bool
        }

        public typealias Response = SubjectTest
    }

    public typealias Update = Create

    public struct TestTask: Content {
        public let testTaskID: SubjectTest.Pivot.Task.ID
        public let isCurrent: Bool
    }
}
