import Vapor

extension TaskDiscussion {

    public enum Update {

        public struct Data: Content {
            public let description: String
        }

        public struct Response: Content {

        }
    }

}
