import Vapor
import FluentKit
import FluentSQL

struct VaporFourMigration: Migration {

    struct OldDB: Codable {
        let response: String
        let userID: User.ID
        let discussionID: TaskDiscussion.ID
    }

    func prepare(on database: Database) -> EventLoopFuture<Void> {

        guard let sql = database as? SQLDatabase else { return database.eventLoop.future() }

        return sql.select().column("*").from("Response").all(decoding: OldDB.self)
            .flatMapThrowing { responses in
                try responses.map { response in
                    try TaskDiscussionResponse.DatabaseModel(
                        data: TaskDiscussionResponse.Create.Data(
                            response: response.response,
                            discussionID: response.discussionID
                        ),
                        userID: response.userID
                    )
                }
        }.flatMap { responses in
            TaskDiscussionResponse.Migrations.Create()
                .prepare(on: database)
                .flatMap {
                    responses.map { $0.save(on: database) }
                        .flatten(on: database.eventLoop)
            }
        }.flatMap {
            database.schema("Response").delete()
        }.flatMap {
            SubtopicTopicIDColumn().prepare(on: database)
        }.flatMap {
            TopicSubjectIDColumn().prepare(on: database)
        }
    }

    func revert(on database: Database) -> EventLoopFuture<Void> {
        database.eventLoop.future()
    }

    struct SubtopicTopicIDColumn: Migration {

        func prepare(on database: Database) -> EventLoopFuture<Void> {
            guard let sql = database as? SQLDatabase else { return database.eventLoop.future() }

            return sql.raw("ALTER TABLE \"Subtopic\" RENAME COLUMN \"topicId\" TO \"topicID\";").run()
        }

        func revert(on database: Database) -> EventLoopFuture<Void> {
            guard let sql = database as? SQLDatabase else { return database.eventLoop.future() }

            return sql.raw("ALTER TABLE \"Subtopic\" RENAME COLUMN \"topicID\" TO \"topicId\";").run()
        }
    }

    struct TopicSubjectIDColumn: Migration {

        func prepare(on database: Database) -> EventLoopFuture<Void> {
            guard let sql = database as? SQLDatabase else { return database.eventLoop.future() }

            return sql.raw("ALTER TABLE \"Topic\" RENAME COLUMN \"subjectId\" TO \"subjectID\";").run()
        }

        func revert(on database: Database) -> EventLoopFuture<Void> {
            guard let sql = database as? SQLDatabase else { return database.eventLoop.future() }

            return sql.raw("ALTER TABLE \"Topic\" RENAME COLUMN \"subjectID\" TO \"subjectId\";").run()
        }
    }
}
