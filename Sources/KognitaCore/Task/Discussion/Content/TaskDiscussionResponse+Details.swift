import Vapor

extension TaskDiscussion.Pivot.Response {

    public struct Details: Content {

        public let response: String
        public let createdAt: Date?
        public let username: String
    }
}
