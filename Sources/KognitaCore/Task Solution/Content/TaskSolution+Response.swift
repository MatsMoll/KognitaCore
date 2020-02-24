import Vapor

extension TaskSolution {
    public struct Response: Content {
        public let createdAt: Date?
        public let solution: String
        public var creatorUsername: String?
        public let presentUser: Bool
        public let approvedBy: String?
        public let numberOfVotes: Int

        init(queryResponse: Repository.Query.Response, numberOfVotes: Int) {
            self.createdAt = queryResponse.createdAt
            self.solution = queryResponse.solution
            self.creatorUsername = queryResponse.creatorUsername
            self.presentUser = queryResponse.presentUser
            self.approvedBy = queryResponse.approvedBy
            self.numberOfVotes = numberOfVotes
        }
    }
}
