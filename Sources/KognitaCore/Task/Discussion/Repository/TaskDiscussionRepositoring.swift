import Vapor

public protocol TaskDiscussionRepositoring:
    CreateModelRepository,
    UpdateModelRepository
    where
    Model           == TaskDiscussion,
    CreateData      == TaskDiscussion.Create.Data,
    CreateResponse  == TaskDiscussion.Create.Response,
    UpdateData      == TaskDiscussion.Update.Data,
    UpdateResponse  == TaskDiscussion.Update.Response
{
    static func respond(with response: TaskDiscussion.Pivot.Response.Create.Data, by user: User, on conn: DatabaseConnectable) throws -> EventLoopFuture<Void>

    static func responses(to discussionID: TaskDiscussion.ID, on conn: DatabaseConnectable) throws -> EventLoopFuture<[TaskDiscussion.Pivot.Response.Details]>

    static func getDiscussions(in taskID: Task.ID, on conn: DatabaseConnectable) throws -> EventLoopFuture<[TaskDiscussion.Details]>

    static func getUserDiscussions(for user: User, on conn: DatabaseConnectable) throws -> EventLoopFuture<[TaskDiscussion.Details]>

    static func setRecentlyVisited(for user: User, on conn: DatabaseConnectable) throws -> EventLoopFuture<Bool>
}
