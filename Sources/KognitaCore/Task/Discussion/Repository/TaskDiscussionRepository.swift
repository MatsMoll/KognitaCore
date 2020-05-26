import Vapor
import FluentPostgreSQL

extension TaskDiscussion {
    struct DatabaseRepository: TaskDiscussionRepositoring, DatabaseConnectableRepository {

        typealias DatabaseModel = TaskDiscussion.DatabaseModel

        let conn: DatabaseConnectable

        public func getDiscussions(in taskID: Task.ID) throws -> EventLoopFuture<[TaskDiscussion]> {
            TaskDiscussion.DatabaseModel.query(on: conn)
                .filter(\TaskDiscussion.DatabaseModel.taskID == taskID)
                .join(\User.DatabaseModel.id, to: \TaskDiscussion.DatabaseModel.userID)
                .alsoDecode(User.DatabaseModel.self)
                .all()
                .map { discussions in

                    return discussions.map { (discussion, user) in

                        TaskDiscussion(
                            id: discussion.id ?? 0,
                            description: discussion.description,
                            createdAt: discussion.createdAt,
                            username: user.username,
                            newestResponseCreatedAt: .now
                        )
                    }
            }
        }

        public func getUserDiscussions(for user: User) throws -> EventLoopFuture<[TaskDiscussion]> {
            return conn.databaseConnection(to: .psql)
                .flatMap { psqlConn in
                    psqlConn.select()
                        .all(table: TaskDiscussion.DatabaseModel.self)
                        .column(\User.DatabaseModel.username)
                        .column(\TaskDiscussionResponse.DatabaseModel.createdAt, as: "newestResponseCreatedAt")
                        .from(TaskDiscussion.DatabaseModel.self)
                        .join(\TaskDiscussion.DatabaseModel.id, to: \TaskDiscussionResponse.DatabaseModel.discussionID)
                        .join(\TaskDiscussion.DatabaseModel.userID, to: \User.DatabaseModel.id)
                        .where(\TaskDiscussion.DatabaseModel.userID == user.id)
                        .orderBy(\TaskDiscussionResponse.DatabaseModel.createdAt, .descending)
                        .all(decoding: TaskDiscussion.self)
                        .map { discussions in

                            discussions.removingDuplicates()
                    }

            }
        }

        public func setRecentlyVisited(for user: User) throws -> EventLoopFuture<Bool> {

            var query = TaskDiscussionResponse.DatabaseModel.query(on: conn)
                .filter(\.userID == user.id)

            // FIXME: - Add variable
//            if let recentlyVisited = user.viewedNotificationsAt {
//                query = query.filter(\.createdAt > recentlyVisited)
//            }

            return query.count()
                .map { numberOfResponses in
                    return numberOfResponses > 0
            }
        }

        public func getLastResponse(for user: User) throws -> EventLoopFuture<TaskDiscussionResponse.DatabaseModel?> {

            TaskDiscussionResponse.DatabaseModel.query(on: conn)
                .filter(\.userID == user.id)
                .sort(\.createdAt, .descending)
                .first()
        }

        public func create(from content: TaskDiscussion.Create.Data, by user: User?) throws -> EventLoopFuture<Void> {

            guard let user = user else {
                throw Abort(.unauthorized)
            }

            return try TaskDiscussion.DatabaseModel(data: content, userID: user.id)
                .create(on: conn)
                .transform(to: ())
        }

        public func update(model: TaskDiscussion.DatabaseModel, to data: TaskDiscussion.Update.Data, by user: User) throws -> EventLoopFuture<Void> {

            guard user.id == model.userID else {
                throw Abort(.forbidden)
            }
            try model.update(with: data)
            return model.save(on: conn)
                .transform(to: ())
        }

        public func respond(with response: TaskDiscussionResponse.Create.Data, by user: User) throws -> EventLoopFuture<Void> {

            return try TaskDiscussionResponse.DatabaseModel(data: response, userID: user.id)
                .create(on: conn)
                .transform(to: ())
        }

        public func responses(to discussionID: TaskDiscussion.ID, for user: User) throws -> EventLoopFuture<[TaskDiscussionResponse]> {

            let oldViewedDate: Date? = nil
//            user.viewedNotificationsAt = Date()

//            return user.save(on: conn).flatMap { _ in
                return TaskDiscussionResponse.DatabaseModel.query(on: self.conn)
                    .filter(\TaskDiscussionResponse.DatabaseModel.discussionID == discussionID)
                    .join(\User.DatabaseModel.id, to: \TaskDiscussionResponse.DatabaseModel.userID)
                    .sort(\TaskDiscussionResponse.DatabaseModel.createdAt, .ascending)
                    .alsoDecode(User.DatabaseModel.self)
                    .all()
                    .map { responses in
                        responses.map { response, user in
                            var isNew = true
                            if
                                let oldDate = oldViewedDate,
                                let responseDate = response.createdAt
                            {
                                isNew = responseDate > oldDate
                            }

                            return TaskDiscussionResponse(
                                response: response.response,
                                createdAt: response.createdAt,
                                username: user.username,
                                isNew: isNew
                            )
                        }
                }
//            }
        }
    }
}
