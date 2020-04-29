import Vapor
import FluentPostgreSQL
@testable import KognitaCore

extension TaskDiscussion {
    public static func create(description: String = "Some description", userID: User.ID? = nil, taskID: Task.ID? = nil, on conn: PostgreSQLConnection) throws -> TaskDiscussion {

        let creatorUserID = try userID ?? User.create(on: conn).requireID()
        let taskOneID = try taskID ?? Task.create(on: conn).requireID()

        let data = TaskDiscussion.Create.Data(
            description: description,
            taskID: taskOneID
        )

        return try TaskDiscussion.init(data: data, userID: creatorUserID)
            .save(on: conn)
            .wait()
    }
}
