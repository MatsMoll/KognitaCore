import Vapor
import FluentKit
@testable import KognitaCore

extension TaskDiscussion {
    public static func create(description: String = "Some description", userID: User.ID? = nil, taskID: Task.ID? = nil, on app: Application) throws -> TaskDiscussion.DatabaseModel {

        let creatorUserID = try userID ?? User.create(on: app).id
        let taskOneID = try taskID ?? TaskDatabaseModel.create(on: app).requireID()

        let data = TaskDiscussion.Create.Data(
            description: description,
            taskID: taskOneID
        )

        let discussion = TaskDiscussion.DatabaseModel(data: data, userID: creatorUserID)

        return try discussion.save(on: app.db)
            .transform(to: discussion)
            .wait()
    }
}
