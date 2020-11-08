import Vapor
import Fluent
import FluentSQL

extension QueryBuilder {
    func join<From, To>(parent: KeyPath<From, ParentProperty<From, To>>) -> Self {
        join(To.self, on: parent.appending(path: \.$id) == \To._$id)
    }

    func join<From, To>(parent: KeyPath<From, OptionalParentProperty<From, To>>, method: DatabaseQuery.Join.Method = .left) -> Self {
        join(To.self, on: parent.appending(path: \.$id) == \To._$id, method: method)
    }

    func join<From, To>(superclass: To.Type, with: From.Type, method: DatabaseQuery.Join.Method = .inner) -> Self where From: FluentKit.Model, To: FluentKit.Model, To.IDValue == From.IDValue {
        join(To.self, on: \From._$id == \To._$id, method: method)
    }

    func join<From, To>(from: From.Type, to toType: To.Type, method: DatabaseQuery.Join.Method = .inner) -> Self where From: FluentKit.Model, To: FluentKit.Model, To.IDValue == From.IDValue {
        join(To.self, on: \From._$id == \To._$id, method: method)
    }

    func join<From, To>(children: KeyPath<From, ChildrenProperty<From, To>>) -> Self {
        switch From()[keyPath: children].parentKey {
        case .optional(let parent): return join(To.self, on: \From._$id == parent.appending(path: \.$id))
        case .required(let parent): return join(To.self, on: \From._$id == parent.appending(path: \.$id))
        }
    }

    func join<From, To, Through>(siblings: KeyPath<From, SiblingsProperty<From, To, Through>>) -> Self where From: FluentKit.Model, To: FluentKit.Model, Through: FluentKit.Model {
        let siblings = From()[keyPath: siblings]
        return join(Through.self, on: siblings.from.appending(path: \.$id) == \From._$id)
            .join(To.self, on: siblings.to.appending(path: \.$id) == \To._$id)
    }
}

extension SQLSelectBuilder {
    func join<From, To>(parent: KeyPath<From, ParentProperty<From, To>>) -> Self {
        join(To.schema, on: "\"\(From.schemaOrAlias)\".\"\(From()[keyPath: parent.appending(path: \.$id)].key.description)\"=\"\(To.schemaOrAlias)\".\"\(To()._$id.key.description)\"")
    }
}

extension TaskDiscussion {
    public struct DatabaseRepository: TaskDiscussionRepositoring, DatabaseConnectableRepository {

        public init(database: Database) {
            self.database = database
        }

        public let database: Database

        public func getDiscussions(in taskID: Task.ID) throws -> EventLoopFuture<[TaskDiscussion]> {

            return TaskDiscussion.DatabaseModel.query(on: database)
                .filter(\.$task.$id == taskID)
                .join(parent: \TaskDiscussion.DatabaseModel.$user)
                .all(TaskDiscussion.DatabaseModel.self, User.DatabaseModel.self)
                .mapEach { (discussion, user) in
                    TaskDiscussion(
                        id: discussion.id ?? 0,
                        description: discussion.description,
                        createdAt: discussion.createdAt,
                        username: user.username,
                        newestResponseCreatedAt: .now
                    )
            }
        }

        public func getUserDiscussions(for user: User) throws -> EventLoopFuture<[TaskDiscussion]> {
            TaskDiscussion.DatabaseModel.query(on: database)
                .join(children: \TaskDiscussion.DatabaseModel.$responses)
                .join(parent: \TaskDiscussion.DatabaseModel.$user)
                .filter(\TaskDiscussion.DatabaseModel.$user.$id == user.id)
                .sort(TaskDiscussionResponse.DatabaseModel.self, \TaskDiscussionResponse.DatabaseModel.$createdAt, .descending)
                .all(TaskDiscussion.DatabaseModel.self, User.DatabaseModel.self, TaskDiscussionResponse.DatabaseModel.self)
                .flatMapEachThrowing { (discussion, user, response) in
                    try TaskDiscussion(
                        id: discussion.requireID(),
                        description: discussion.description,
                        createdAt: discussion.createdAt ?? .now,
                        username: user.username,
                        newestResponseCreatedAt: response.createdAt ?? .now
                    )
                }
                .map { $0.removingDuplicates() }
        }

        public func setRecentlyVisited(for user: User) throws -> EventLoopFuture<Bool> {

            var query = TaskDiscussionResponse.DatabaseModel.query(on: database)
                .filter(\.$user.$id == user.id)

            // FIXME: - Add variable
//            if let recentlyVisited = user.viewedNotificationsAt {
//                query = query.filter(\.createdAt > recentlyVisited)
//            }

            return query.count()
                .map { numberOfResponses in
                    return numberOfResponses > 0
            }
        }

        func getLastResponse(for user: User) throws -> EventLoopFuture<TaskDiscussionResponse.DatabaseModel?> {

            TaskDiscussionResponse.DatabaseModel.query(on: database)
                .filter(\.$user.$id == user.id)
                .sort(\.$createdAt, .descending)
                .first()
        }

        public func create(from content: TaskDiscussion.Create.Data, by user: User?) throws -> EventLoopFuture<NoData> {
            guard content.description.removeCharacters(from: .whitespaces).count > 3 else {
                return database.eventLoop.future(error: Abort(.badRequest))
            }
            guard let user = user else {
                throw Abort(.unauthorized)
            }

            return TaskDiscussion.DatabaseModel(data: content, userID: user.id)
                .create(on: database)
                .transform(to: NoData())
        }

        public func updateModelWith(id: Int, to data: TaskDiscussion.Update.Data, by user: User) throws -> EventLoopFuture<NoData> {
            TaskDiscussion.DatabaseModel.find(id, on: database)
                .unwrap(or: Abort(.badRequest))
                .flatMapThrowing { model -> TaskDiscussion.DatabaseModel in
                    guard user.id == model.user.id else {
                        throw Abort(.forbidden)
                    }
                    model.update(with: data)
                    return model
                }
                .flatMap {
                    $0.save(on: self.database)
                }
                .transform(to: NoData())
        }

        public func respond(with response: TaskDiscussionResponse.Create.Data, by user: User) throws -> EventLoopFuture<Void> {
            guard response.response.removeCharacters(from: .whitespaces).count > 3 else {
                return database.eventLoop.future(error: Abort(.badRequest))
            }
            return try TaskDiscussionResponse.DatabaseModel(data: response, userID: user.id)
                .create(on: database)
                .transform(to: ())
        }

        public func responses(to discussionID: TaskDiscussion.ID, for user: User) throws -> EventLoopFuture<[TaskDiscussionResponse]> {

            let oldViewedDate: Date? = nil
//            user.viewedNotificationsAt = Date()

//            return user.save(on: conn).flatMap { _ in
                return TaskDiscussionResponse.DatabaseModel.query(on: self.database)
                    .filter(\TaskDiscussionResponse.DatabaseModel.$discussion.$id == discussionID)
                    .with(\.$user)
                    .sort(\TaskDiscussionResponse.DatabaseModel.$createdAt, .ascending)
                    .all()
                    .mapEach { response in
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
                            username: response.user.username,
                            isNew: isNew
                        )
                    }
//            }
        }
    }
}
