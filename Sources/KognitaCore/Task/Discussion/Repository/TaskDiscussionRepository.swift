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
                .flatMap { discussions in

                    TaskDiscussion.Pivot.Response.query(on: conn)
                        .join(\TaskDiscussion.id, to: \TaskDiscussion.Pivot.Response.discussionID)
                        .filter(\TaskDiscussion.taskID == taskID)
                        .join(\User.id, to: \TaskDiscussion.Pivot.Response.userID)
                        .alsoDecode(User.self)
                        .all()
                        .map { responses in

                            structureDetailsResponse(discussions: discussions, responses: responses)
                    }
            }
        }

        private static func structureDetailsResponse(discussions: [(TaskDiscussion, User)], responses: [(TaskDiscussion.Pivot.Response, User)]) -> [TaskDiscussion.Details] {

            let groupedResponses = responses
                .group(by: \.0.discussionID)
                .mapValues { responses in
                    responses.map { (response, user) in
                        TaskDiscussion.Pivot.Response.Details(
                            response: response.response,
                            createdAt: response.createdAt,
                            username: user.username
                        )
                    }
            }

            return discussions.map { (discussion, user) in

                TaskDiscussion.Details(
                    description: discussion.description,
                    createdAt: discussion.createdAt,
                    username: user.username,
                    responses: groupedResponses[discussion.id ?? 0] ?? []
                )
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

        public static func update(model: TaskDiscussion, to data: TaskDiscussion.Update.Data, by user: User, on conn: DatabaseConnectable) throws -> EventLoopFuture<TaskDiscussion.Create.Response> {

            guard user.id == model.userID else {
                throw Abort(.forbidden)
            }
            model.update(with: data)
            return model.save(on: conn)
                .transform(to: .init())
        }

        public static func respond(with response: TaskDiscussion.Pivot.Response.Create.Data, by user: User, on conn: DatabaseConnectable) throws -> EventLoopFuture<Void> {

            return try TaskDiscussion.Pivot.Response(data: response, userID: user.requireID())
                .create(on: conn)
                .transform(to: ())
        }
    }
}
