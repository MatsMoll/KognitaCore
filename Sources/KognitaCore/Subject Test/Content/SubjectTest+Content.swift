import Vapor

extension SubjectTest {

    public struct ModifyResponse: Content {

        public let id: SubjectTest.ID
        public let subjectID: Subject.ID
        public let title: String
        public let createdAt: Date
        public let duration: TimeInterval
        public let scheduledAt: Date
        public let openedAt: Date?
        public let taskIDs: [Task.ID]
        public let password: String
        public let isTeamBasedLearning: Bool

        public var isOpen: Bool { openedAt != nil }

        public var endsAt: Date? {
            guard let openedAt = openedAt else {
                return nil
            }
            return openedAt.addingTimeInterval(duration)
        }

        public init(test: SubjectTest, taskIDs: [Task.ID]) {
            self.id = test.id
            self.subjectID = test.subjectID
            self.title = test.title
            self.createdAt = test.createdAt
            self.scheduledAt = test.scheduledAt
            self.duration = test.duration
            self.openedAt = test.openedAt
            self.taskIDs = taskIDs
            self.password = test.password
            self.isTeamBasedLearning = test.isTeamBasedLearning
        }
    }

    public struct ListReponse: Content {
        public let subject: Subject

        public let finnishedTests: [SubjectTest.UserOverview]
        public let unopenedTests: [SubjectTest.UserOverview]
        public var ongoingTests: [SubjectTest.UserOverview]

        public init(subject: Subject, tests: [SubjectTest]) {
            self.subject = subject

            var ongoingTests = [SubjectTest.UserOverview]()
            var unopendTests = [SubjectTest.UserOverview]()
            var finnishedTests = [SubjectTest.UserOverview]()

            tests.forEach { test in
                do {
                    if test.endedAt == nil {
//                        try unopendTests.append(test.response(with: subject))
                    } else if test.isOpen {
//                        try ongoingTests.append(test.response(with: subject))
                    } else {
//                        try finnishedTests.append(test.response(with: subject))
                    }
                } catch {
                    print("SubjectTest.ListResponse Error: ", error.localizedDescription)
                }
            }
            self.ongoingTests = ongoingTests
            self.unopenedTests = unopendTests
            self.finnishedTests = finnishedTests
        }
    }
}
