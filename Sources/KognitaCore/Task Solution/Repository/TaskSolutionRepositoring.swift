import Vapor

public protocol TaskSolutionRepositoring: DeleteModelRepository {

    func create(from content: TaskSolution.Create.Data, by user: User?) throws -> EventLoopFuture<TaskSolution>

    func updateModelWith(id: Int, to data: TaskSolution.Update.Data, by user: User) throws -> EventLoopFuture<TaskSolution>

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

    func solutionsFor(subjectID: Subject.ID) -> EventLoopFuture<[TaskSolution]>
}
