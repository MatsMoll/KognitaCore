import Vapor

extension TaskDiscussion {

    public struct Details: Content {

        public let id: TaskDiscussion.ID
        public let description: String
        public let createdAt: Date?
        public let username: String
    }
}