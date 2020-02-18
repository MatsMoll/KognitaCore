
import Vapor


extension TaskSession {

    public struct HistoryList: Content {

        public struct PracticeSessionContent: Content {
            public let session: PracticeSession
            public let subject: Subject
        }

        public let testSessions: [TestSession.HighOverview]
        public let practiceSessions: [PracticeSession.HighOverview]

        public init(testSessions: [TestSession.HighOverview], practiceSessions: [PracticeSession.HighOverview]) {
            self.testSessions = testSessions
            self.practiceSessions = practiceSessions
        }
    }
}

extension PracticeSession {
    public struct HistoryList: Content {

        public struct Session: Content {
            public let session: PracticeSession
            public let subject: Subject
        }

        public let sessions: [Session]
    }

    public struct HighOverview: Content {

        public let id: TaskSession.ID
        public let createdAt: Date
        public let subjectName: String
        public let subjectID: Subject.ID
    }

}
