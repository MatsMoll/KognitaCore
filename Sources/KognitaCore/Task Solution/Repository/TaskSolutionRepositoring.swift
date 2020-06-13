import Vapor

public protocol TaskSolutionRepositoring: CreateModelRepository,
    UpdateModelRepository,
    DeleteModelRepository
    where
    ID              == Int,
    CreateData      == TaskSolution.Create.Data,
    CreateResponse  == TaskSolution,
    UpdateData      == TaskSolution.Update.Data,
    UpdateResponse  == TaskSolution {
    func solutions(for taskID: Task.ID, for user: User) -> EventLoopFuture<[TaskSolution.Response]>

    /// Upvote a solution
    func upvote(for solutionID: TaskSolution.ID, by user: User) throws -> EventLoopFuture<Void>

    /// Downvote/revoke vote on a solution
    func revokeVote(for solutionID: TaskSolution.ID, by user: User) throws -> EventLoopFuture<Void>

    /// Approves a `TaskSolution`
    /// - Parameters:
    ///   - solutionID: The `TaskSolutions`s id
    ///   - user: The user approving the solution
    ///   - conn: The database connection
    func approve(for solutionID: TaskSolution.ID, by user: User) throws -> EventLoopFuture<Void>

    func unverifiedSolutions(in subjectID: Subject.ID, for moderator: User) throws -> EventLoopFuture<[TaskSolution.Unverified]>
}
