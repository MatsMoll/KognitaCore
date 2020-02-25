import Vapor


extension TaskDiscussion {

    public enum Create {

        public struct Data: Content {
            public let description: String
            public let taskID: Task.ID
        }

        public struct Response: Content {

        }
    }
}
