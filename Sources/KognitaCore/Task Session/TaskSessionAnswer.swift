import Foundation
import Vapor
import FluentKit

final class TaskSessionAnswer: KognitaPersistenceModel {

    public static var tableName: String = "TaskSessionAnswer"

    @Timestamp(key: "createdAt", on: .create)
    public var createdAt: Date?

    @Timestamp(key: "updatedAt", on: .update)
    public var updatedAt: Date?

    @DBID(custom: "id")
    public var id: Int?

    @Parent(key: "sessionID")
    var session: TaskSession

    @Parent(key: "taskAnswerID")
    var taskAnswer: TaskAnswer

    init(sessionID: TaskSession.IDValue, taskAnswerID: TaskAnswer.IDValue) {
        self.$session.id = sessionID
        self.$taskAnswer.id = taskAnswerID
    }

    init() {}
}

extension TaskSessionAnswer {
    enum Migrations {}
}

extension TaskSessionAnswer.Migrations {
    struct Create: KognitaModelMigration {
        typealias Model = TaskSessionAnswer

        func build(schema: SchemaBuilder) -> SchemaBuilder {
            schema.field("sessionID", .uint, .required, .references(TaskSession.schema, .id, onDelete: .cascade, onUpdate: .cascade))
                .field("taskAnswerID", .uint, .required, .references(TaskAnswer.schema, .id, onDelete: .cascade, onUpdate: .cascade))
                .defaultTimestamps()
        }
    }
}

protocol TaskSessionAnswerRepository {
    func multipleChoiseAnswers(in sessionID: TaskSession.IDValue, taskID: Task.ID) -> EventLoopFuture<[MultipleChoiseTaskAnswer]>
    func flashCardAnswers(in sessionID: TaskSession.IDValue, taskID: Task.ID) -> EventLoopFuture<FlashCardAnswer?>
}

extension TaskSessionAnswer {

    public struct DatabaseRepository: TaskSessionAnswerRepository, DatabaseConnectableRepository {

        public let database: Database

        public func multipleChoiseAnswers(in sessionID: TaskSession.IDValue, taskID: Task.ID) -> EventLoopFuture<[MultipleChoiseTaskAnswer]> {
            database.eventLoop.future([])
//            MultipleChoiseTaskAnswer.query(on: db)
//                .withDeleted()
//                .join(\TaskSessionAnswer.taskAnswerID, to: \MultipleChoiseTaskAnswer.id)
//                .join(\MultipleChoiseTaskChoise.id, to: \MultipleChoiseTaskAnswer.choiseID)
//                .filter(\TaskSessionAnswer.sessionID == sessionID)
//                .filter(\MultipleChoiseTaskChoise.taskId == taskID)
//                .all()
        }

        public func flashCardAnswers(in sessionID: TaskSession.IDValue, taskID: Task.ID) -> EventLoopFuture<FlashCardAnswer?> {
            database.eventLoop.future(nil)
//            FlashCardAnswer.query(on: conn)
//                .join(\TaskSessionAnswer.taskAnswerID, to: \FlashCardAnswer.id)
//                .filter(\TaskSessionAnswer.sessionID == sessionID)
//                .filter(\FlashCardAnswer.taskID == taskID)
//                .first()
        }
    }
}
