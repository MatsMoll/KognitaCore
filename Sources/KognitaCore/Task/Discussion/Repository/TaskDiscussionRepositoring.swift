import Vapor

public protocol TaskDiscussionRepositoring:
    CreateModelRepository,
    UpdateModelRepository
    where
    Model           == TaskDiscussion,
    CreateData      == TaskDiscussion.Create.Data,
    CreateResponse  == TaskDiscussion.Create.Response,
    UpdateData      == TaskDiscussion.Update.Data,
    UpdateResponse  == TaskDiscussion.Create.Response
{
    static func respond(with response: TaskDiscussion.Pivot.Response.Create.Data, by user: User, on conn: DatabaseConnectable) throws -> EventLoopFuture<Void>
}
