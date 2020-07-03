import Vapor

extension TaskSolution.Response {

    init(solution: TaskSolution.DatabaseModel, numberOfVotes: Int, userHasVoted: Bool) {

        var creatorUsername = "Unknown"
        if solution.presentUser {
            creatorUsername = solution.creator.username
        }

        self.init(
            id: solution.id ?? 0,
            createdAt: solution.createdAt ?? .now,
            solution: solution.solution,
            creatorID: solution.$creator.id,
            creatorUsername: creatorUsername,
            presentUser: solution.presentUser,
            approvedBy: solution.approvedBy?.username,
            numberOfVotes: numberOfVotes,
            userHasVoted: userHasVoted
        )
    }
}
