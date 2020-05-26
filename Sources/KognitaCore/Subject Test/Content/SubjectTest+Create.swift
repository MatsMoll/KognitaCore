import Vapor

extension SubjectTest {
    public struct TestTask: Content {
        public let testTaskID: Int
        public let isCurrent: Bool
    }
}
