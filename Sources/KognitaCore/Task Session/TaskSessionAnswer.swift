import Foundation
import Vapor
import FluentKit
import Fluent

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
    func multipleChoiseAnswers(in sessionID: Sessions.ID, taskID: Task.ID, choices: [MultipleChoiceTaskChoice]) -> EventLoopFuture<[MultipleChoiceTaskChoice.Answered]>
    func typingTaskAnswer(in sessionID: Sessions.ID, taskID: Task.ID) -> EventLoopFuture<TypingTask.Answer?>
}

extension TaskSessionAnswer {

    public struct DatabaseRepository: TaskSessionAnswerRepository, DatabaseConnectableRepository {

        public let database: Database

        public func multipleChoiseAnswers(in sessionID: Sessions.ID, taskID: Task.ID, choices: [MultipleChoiceTaskChoice]) -> EventLoopFuture<[MultipleChoiceTaskChoice.Answered]> {

            MultipleChoiseTaskAnswer.query(on: database)
                .withDeleted()
                .join(TaskSessionAnswer.self, on: \TaskSessionAnswer.$taskAnswer.$id == \MultipleChoiseTaskAnswer.$id)
                .filter(\MultipleChoiseTaskAnswer.$choice.$id ~~ choices.map { $0.id })
                .filter(TaskSessionAnswer.self, \TaskSessionAnswer.$session.$id == sessionID)
                .all()
                .map { answers in
                    choices.map { choice in
                        MultipleChoiceTaskChoice.Answered(
                            id: choice.id,
                            choice: choice.choice,
                            wasSelected: answers.contains(where: { $0.$choice.id == choice.id }),
                            isCorrect: choice.isCorrect
                        )
                    }
            }
        }

        public func typingTaskAnswer(in sessionID: Sessions.ID, taskID: Task.ID) -> EventLoopFuture<TypingTask.Answer?> {

            FlashCardAnswer.query(on: database)
                .join(TaskSessionAnswer.self, on: \TaskSessionAnswer.$taskAnswer.$id == \FlashCardAnswer.$id)
                .filter(TaskSessionAnswer.self, \TaskSessionAnswer.$session.$id == sessionID)
                .filter(\FlashCardAnswer.$task.$id == taskID)
                .first()
                .optionalMap { TypingTask.Answer(answer: $0.answer) }
        }
    }
}
