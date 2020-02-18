import Vapor

extension SubjectTest {
    public struct CompletionStatus: Content {
        public internal(set) var amountOfCompletedUsers: Int
        public internal(set) var amountOfEnteredUsers: Int

        public var hasEveryoneCompleted: Bool { amountOfEnteredUsers == amountOfCompletedUsers }
    }
}
