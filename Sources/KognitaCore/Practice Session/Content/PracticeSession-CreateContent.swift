import Vapor

extension PracticeSession {

    public enum Create {

        public struct Data: Decodable {
            /// The number of task to complete in a session
            public let numberOfTaskGoal: Int

            /// The topic id's for the tasks to map
            public let subtopicsIDs: Set<Subtopic.ID>?

            public let topicIDs: Set<Topic.ID>?
        }

        public typealias Response = PracticeSession
    }

    public typealias Edit = Create
}
