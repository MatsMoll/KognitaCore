import Vapor


extension TaskDiscussion {
    public class DatabaseRepository: TaskDiscussionRepositoring {

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
