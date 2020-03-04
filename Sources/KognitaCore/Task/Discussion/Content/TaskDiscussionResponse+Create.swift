import Vapor

extension TaskDiscussion.Pivot.Response {

    public enum Create {

        public struct Data: Content {
            public let response: String
            public let discussionID: TaskDiscussion.ID
        }

        public struct Response: Content {
            public init() {}
        }
    }
}
