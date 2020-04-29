import Vapor

extension PracticeSession {
    public struct Result: Content {
        public let subject: Subject.Overview
        public let results: [PracticeSession.TaskResult]

        public init(subject: Subject.Overview, results: [PracticeSession.TaskResult]) {
            self.subject = subject
            self.results = results
        }
    }
}
