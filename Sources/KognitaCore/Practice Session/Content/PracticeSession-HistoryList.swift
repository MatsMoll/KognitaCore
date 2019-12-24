
import Vapor

extension PracticeSession {
    public struct HistoryList: Content {

        public struct Session: Content {
            public let session: PracticeSession
            public let subject: Subject
        }

        public let sessions: [Session]
    }
}
