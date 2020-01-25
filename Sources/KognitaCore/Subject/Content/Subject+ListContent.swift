import Vapor

extension Subject {
    public struct ListContent: Content {
        public let subjects: [Subject]
        public let ongoingPracticeSession: PracticeSession.ID?
        public let ongoingTestSession: TestSession.ID?
        public let openedTest: SubjectTest.OverviewResponse?

        public init(subjects: [Subject], ongoingPracticeSession: PracticeSession.ID?, ongoingTestSession: TestSession.ID?, openedTest: SubjectTest.OverviewResponse?) {
            self.subjects = subjects
            self.ongoingTestSession = ongoingTestSession
            self.ongoingPracticeSession = ongoingPracticeSession
            self.openedTest = openedTest
        }
    }
}
