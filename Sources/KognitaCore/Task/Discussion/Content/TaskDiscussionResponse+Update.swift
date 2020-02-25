import Vapor

extension TaskDiscussion.Pivot.Response {

    public enum Update {

        public struct Data: Content {
            public let response: String
        }

        public struct Response: Content {

        }
    }
}
