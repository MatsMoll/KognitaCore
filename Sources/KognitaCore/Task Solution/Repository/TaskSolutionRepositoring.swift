import Vapor


public protocol TaskSolutionRepositoring:
    CreateModelRepository,
    UpdateModelRepository,
    DeleteModelRepository
    where
    Model           == TaskSolution,
    CreateData      == TaskSolution.Create.Data,
    CreateResponse  == TaskSolution.Create.Response,
    UpdateData      == TaskSolution.Update.Data,
    UpdateResponse  == TaskSolution.Update.Response
{
    static func solutions(for taskID: Task.ID, on conn: DatabaseConnectable) -> EventLoopFuture<[TaskSolution.Response]>

    /// Upvote a solution
    static func upvote(for solutionID: TaskSolution.ID, by user: User, on conn: DatabaseConnectable) throws -> EventLoopFuture<Void>

    /// Downvote/revoke vote on a solution
    static func revokeVote(for solutionID: TaskSolution.ID, by user: User, on conn: DatabaseConnectable) throws -> EventLoopFuture<Void>
}
