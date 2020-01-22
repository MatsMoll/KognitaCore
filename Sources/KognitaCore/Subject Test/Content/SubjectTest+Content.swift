import Vapor

extension SubjectTest {

    public struct OverviewResponse: Content {

        public let id: SubjectTest.ID
        public let subjectName: String
        public let title: String
        public let createdAt: Date
        public let duration: TimeInterval
        public let scheduledAt: Date
        public let openedAt: Date?

        public var isOpen: Bool { openedAt != nil }

        public var endsAt: Date? {
            guard let openedAt = openedAt else {
                return nil
            }
            return openedAt.addingTimeInterval(duration)
        }

        init(test: SubjectTest, subjectName: String) {
            self.id = test.id ?? 0
            self.title = test.title
            self.createdAt = test.createdAt ?? .now
            self.scheduledAt = test.scheduledAt
            self.duration = test.duration
            self.openedAt = test.openedAt
            self.subjectName = subjectName
        }
    }

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

        public var isOpen: Bool { openedAt != nil }

        public var endsAt: Date? {
            guard let openedAt = openedAt else {
                return nil
            }
            return openedAt.addingTimeInterval(duration)
        }

        public init(test: SubjectTest, taskIDs: [Task.ID]) {
            self.id = test.id ?? 0
            self.subjectID = test.subjectID
            self.title = test.title
            self.createdAt = test.createdAt ?? .now
            self.scheduledAt = test.scheduledAt
            self.duration = test.duration
            self.openedAt = test.openedAt
            self.taskIDs = taskIDs
            self.password = test.password
        }
    }


    public struct ListReponse: Content {
        public let subject: Subject
        public let tests: [SubjectTest.OverviewResponse]

        public init(subject: Subject, tests: [SubjectTest]) {
            self.subject = subject
            self.tests = tests.map { $0.response(with: subject) }
        }
    }
}

