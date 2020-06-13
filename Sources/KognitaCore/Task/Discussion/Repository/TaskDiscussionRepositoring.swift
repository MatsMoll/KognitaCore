import Vapor

public protocol TaskDiscussionRepositoring: CreateModelRepository,
    UpdateModelRepository
    where
    ID              == Int,
    CreateData      == TaskDiscussion.Create.Data,
    CreateResponse  == TaskDiscussion.Create.Response,
    UpdateData      == TaskDiscussion.Update.Data,
    UpdateResponse  == TaskDiscussion.Update.Response {
    func respond(with response: TaskDiscussionResponse.Create.Data, by user: User) throws -> EventLoopFuture<Void>

    func responses(to discussionID: TaskDiscussion.ID, for user: User) throws -> EventLoopFuture<[TaskDiscussionResponse]>

    func getDiscussions(in taskID: Task.ID) throws -> EventLoopFuture<[TaskDiscussion]>

    func getUserDiscussions(for user: User) throws -> EventLoopFuture<[TaskDiscussion]>

    func setRecentlyVisited(for user: User) throws -> EventLoopFuture<Bool>
}
