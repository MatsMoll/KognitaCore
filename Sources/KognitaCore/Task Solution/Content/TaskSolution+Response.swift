import Vapor

extension TaskSolution {
    public struct Response: Content {
        public let id: TaskSolution.ID
        public let createdAt: Date?
        public let solution: String
        public var creatorID: User.ID
        public var creatorUsername: String
        public let presentUser: Bool
        public let approvedBy: String?
        public let numberOfVotes: Int
        public let userHasVoted: Bool

        init(solution: TaskSolution.DatabaseModel, numberOfVotes: Int, userHasVoted: Bool) {
            self.createdAt = solution.createdAt
            self.solution = solution.solution
            self.creatorID = solution.$creator.id
            if solution.presentUser {
                self.creatorUsername = solution.creator.username
            } else {
                self.creatorUsername = "Unknown"
            }
            self.presentUser = solution.presentUser
            self.approvedBy = solution.approvedBy?.username
            self.id = solution.id ?? 0
            self.numberOfVotes = numberOfVotes
            self.userHasVoted = userHasVoted
        }
    }
}
