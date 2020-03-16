import Vapor
import FluentPostgreSQL

extension TaskDiscussion {
    public class DatabaseRepository: TaskDiscussionRepositoring {

        public static func getDiscussions(in taskID: Task.ID, on conn: DatabaseConnectable) throws -> EventLoopFuture<[TaskDiscussion.Details]> {
            TaskDiscussion.query(on: conn)
                .filter(\TaskDiscussion.taskID == taskID)
                .join(\User.id, to: \TaskDiscussion.userID)
                .alsoDecode(User.self)
                .all()
                .map { discussions in

                    return discussions.map { (discussion, user) in

                        TaskDiscussion.Details(
                            id: discussion.id ?? 0,
                            description: discussion.description,
                            createdAt: discussion.createdAt,
                            username: user.username
                        )
                    }
            }
        }

        public static func create(from content: TaskDiscussion.Create.Data, by user: User?, on conn: DatabaseConnectable) throws -> EventLoopFuture<TaskDiscussion.Create.Response> {

            guard let user = user else {
                throw Abort(.unauthorized)
            }

            return try TaskDiscussion(data: content, userID: user.requireID())
                .create(on: conn)
                .transform(to: .init())
        }

        public static func update(model: TaskDiscussion, to data: TaskDiscussion.Update.Data, by user: User, on conn: DatabaseConnectable) throws -> EventLoopFuture<TaskDiscussion.Update.Response> {

            guard user.id == model.userID else {
                throw Abort(.forbidden)
            }
            try model.update(with: data)
            return model.save(on: conn)
                .transform(to: .init())
        }

        public static func respond(with response: TaskDiscussion.Pivot.Response.Create.Data, by user: User, on conn: DatabaseConnectable) throws -> EventLoopFuture<Void> {

            return try TaskDiscussion.Pivot.Response(data: response, userID: user.requireID())
                .create(on: conn)
                .transform(to: ())
        }

        public static func responses(to discussionID: TaskDiscussion.ID, on conn: DatabaseConnectable) throws -> EventLoopFuture<[TaskDiscussion.Pivot.Response.Details]> {

            TaskDiscussion.Pivot.Response.query(on: conn)
                .filter(\TaskDiscussion.Pivot.Response.discussionID == discussionID)
                .join(\User.id, to: \TaskDiscussion.Pivot.Response.userID)
                .sort(\TaskDiscussion.Pivot.Response.createdAt, .ascending)
                .alsoDecode(User.self)
                .all()
                .map { responses in
                    responses.map { response, user in
                        TaskDiscussion.Pivot.Response.Details(
                            response: response.response,
                            createdAt: response.createdAt,
                            username: user.username
                        )
                    }
            }
        }
    }
}
