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
                            username: user.username,
                            newestResponseCreatedAt: .now
                        )
                    }
            }
        }
        
        public static func getUserDiscussions(for user: User, on conn: DatabaseConnectable) throws -> EventLoopFuture<[TaskDiscussion.Details]> {
            return conn.databaseConnection(to: .psql)
                .flatMap { psqlConn in
                    try psqlConn.select()
                        .all(table: TaskDiscussion.self)
                        .column(\User.username)
                        .column(\TaskDiscussion.Pivot.Response.createdAt, as: "newestResponseCreatedAt")
                        .from(TaskDiscussion.self)
                        .join(\TaskDiscussion.id, to: \TaskDiscussion.Pivot.Response.discussionID)
                        .join(\TaskDiscussion.userID, to: \User.id)
                        .where(\TaskDiscussion.userID == user.requireID())
                        .orderBy(\TaskDiscussion.Pivot.Response.createdAt, .descending)
                        .all(decoding: TaskDiscussion.Details.self)
                        .map {  discussions in

                            discussions.removingDuplicates()

                    }

            }
        }

        public static func setRecentlyVisited(for user: User, on conn: DatabaseConnectable) throws -> EventLoopFuture<Bool> {

            var query = try TaskDiscussion.Pivot.Response.query(on: conn)
                .filter(\.userID == user.requireID())

            if let recentlyVisited = user.viewedNotificationsAt {
                query = query.filter(\.createdAt > recentlyVisited)
            }

            return query.count()
                .map { numberOfResponses in
                    return numberOfResponses > 0
            }
        }

        public static func getLastResponse(for user: User, on conn: DatabaseConnectable) throws -> EventLoopFuture<TaskDiscussion.Pivot.Response?> {

            try TaskDiscussion.Pivot.Response.query(on: conn)
                .filter(\.userID == user.requireID())
                .sort(\.createdAt, .descending)
                .first()
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

        public static func responses(to discussionID: TaskDiscussion.ID, for user: User, on conn: DatabaseConnectable) throws -> EventLoopFuture<[TaskDiscussion.Pivot.Response.Details]> {

            let oldViewedDate = user.viewedNotificationsAt
//            user.viewedNotificationsAt = Date()

            return user.save(on: conn).flatMap { _ in
                TaskDiscussion.Pivot.Response.query(on: conn)
                    .filter(\TaskDiscussion.Pivot.Response.discussionID == discussionID)
                    .join(\User.id, to: \TaskDiscussion.Pivot.Response.userID)
                    .sort(\TaskDiscussion.Pivot.Response.createdAt, .ascending)
                    .alsoDecode(User.self)
                    .all()
                    .map { responses in
                        responses.map { response, user in
                            let isNew = response.createdAt! > oldViewedDate!

                            return TaskDiscussion.Pivot.Response.Details(
                                response: response.response,
                                createdAt: response.createdAt,
                                username: user.username,
                                isNew: isNew
                            )
                        }
                }
            }
        }
    }
}
