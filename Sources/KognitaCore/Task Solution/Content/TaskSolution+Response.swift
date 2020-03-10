import Vapor

extension TaskSolution {
    public struct Response: Content {
        public let id: TaskSolution.ID
        public let createdAt: Date?
        public let solution: String
        public var creatorUsername: String
        public let presentUser: Bool
        public let approvedBy: String?
        public let numberOfVotes: Int
        public let userHasVoted: Bool

        init(queryResponse: DatabaseRepository.Query.Response, numberOfVotes: Int, userHasVoted: Bool) {
            self.createdAt = queryResponse.createdAt
            self.solution = queryResponse.solution
            self.creatorUsername = queryResponse.creatorUsername ?? "Unknown"
            self.presentUser = queryResponse.presentUser
            self.approvedBy = queryResponse.approvedBy
            self.id = queryResponse.id
            self.numberOfVotes = numberOfVotes
            self.userHasVoted = userHasVoted
        }
    }
}
