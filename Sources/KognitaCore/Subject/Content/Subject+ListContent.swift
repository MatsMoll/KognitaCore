import Vapor

extension Subject {
    public struct ListContent: Content {
        public let subjects: [Subject.ListOverview]
        public let ongoingPracticeSession: PracticeSession.ID?
        public let ongoingTestSession: TestSession.ID?
        public let openedTest: SubjectTest.OverviewResponse?

        public var activeSubjects: [Subject.ListOverview] { subjects.filter({ $0.isActive }) }
        public var inactiveSubjects: [Subject.ListOverview] { subjects.filter({ $0.isActive == false }) }

        public init(subjects: [Subject.ListOverview], ongoingPracticeSession: PracticeSession.ID?, ongoingTestSession: TestSession.ID?, openedTest: SubjectTest.OverviewResponse?) {
            self.subjects = subjects
            self.ongoingTestSession = ongoingTestSession
            self.ongoingPracticeSession = ongoingPracticeSession
            self.openedTest = openedTest
        }
    }
}
