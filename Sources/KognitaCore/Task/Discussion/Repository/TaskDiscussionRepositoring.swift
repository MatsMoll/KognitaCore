import Vapor

public protocol TaskDiscussionRepositoring {

    func create(from content: TaskDiscussion.Create.Data, by user: User?) throws -> EventLoopFuture<TaskDiscussion.Create.Response>
    func updateModelWith(id: Int, to data: TaskDiscussion.Update.Data, by user: User) throws -> EventLoopFuture<TaskDiscussion.Update.Response>
    func respond(with response: TaskDiscussionResponse.Create.Data, by user: User) throws -> EventLoopFuture<Void>
    func responses(to discussionID: TaskDiscussion.ID, for user: User) throws -> EventLoopFuture<[TaskDiscussionResponse]>
    func getDiscussions(in taskID: Task.ID) throws -> EventLoopFuture<[TaskDiscussion]>
    func getUserDiscussions(for user: User) throws -> EventLoopFuture<[TaskDiscussion]>
    func setRecentlyVisited(for user: User) throws -> EventLoopFuture<Bool>
}
