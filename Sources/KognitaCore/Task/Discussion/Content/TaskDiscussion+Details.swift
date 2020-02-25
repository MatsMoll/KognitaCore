import Vapor

extension TaskDiscussion {

    public struct Details: Content {

        public let description: String
        public let createdAt: Date?
        public let username: String

        public let responses: [TaskDiscussion.Pivot.Response.Details]
    }
}
