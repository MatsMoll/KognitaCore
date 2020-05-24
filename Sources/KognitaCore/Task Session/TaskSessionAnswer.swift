import FluentPostgreSQL
import Foundation
import NIO
import Vapor

public final class TaskSessionAnswer: KognitaPersistenceModel {

    public static var tableName: String = "TaskSessionAnswer"

    public var createdAt: Date?

    public var updatedAt: Date?

    public var id: Int?

    public var sessionID: TaskSession.ID

    public var taskAnswerID: TaskAnswer.ID

    init(sessionID: TaskSession.ID, taskAnswerID: TaskAnswer.ID) {
        self.sessionID = sessionID
        self.taskAnswerID = taskAnswerID
    }

    public static func addTableConstraints(to builder: SchemaCreator<TaskSessionAnswer>) {
        builder.reference(from: \.taskAnswerID, to: \TaskAnswer.id, onUpdate: .cascade, onDelete: .cascade)
        builder.reference(from: \.sessionID, to: \TaskSession.id, onUpdate: .cascade, onDelete: .cascade)
    }
}

protocol TaskSessionAnswerRepository {
    func multipleChoiseAnswers(in sessionID: TaskSession.ID, taskID: Task.ID) -> EventLoopFuture<[MultipleChoiseTaskAnswer]>
    func flashCardAnswers(in sessionID: TaskSession.ID, taskID: Task.ID) -> EventLoopFuture<FlashCardAnswer?>
}

extension TaskSessionAnswer {

    public struct DatabaseRepository: TaskSessionAnswerRepository, DatabaseConnectableRepository {

        public let conn: DatabaseConnectable

        public func multipleChoiseAnswers(in sessionID: TaskSession.ID, taskID: Task.ID) -> EventLoopFuture<[MultipleChoiseTaskAnswer]> {
            MultipleChoiseTaskAnswer.query(on: conn, withSoftDeleted: true)
                .join(\TaskSessionAnswer.taskAnswerID, to: \MultipleChoiseTaskAnswer.id)
                .join(\MultipleChoiseTaskChoise.id, to: \MultipleChoiseTaskAnswer.choiseID)
                .filter(\TaskSessionAnswer.sessionID == sessionID)
                .filter(\MultipleChoiseTaskChoise.taskId == taskID)
                .all()
        }

        public func flashCardAnswers(in sessionID: TaskSession.ID, taskID: Task.ID) -> EventLoopFuture<FlashCardAnswer?> {
            FlashCardAnswer.query(on: conn)
                .join(\TaskSessionAnswer.taskAnswerID, to: \FlashCardAnswer.id)
                .filter(\TaskSessionAnswer.sessionID == sessionID)
                .filter(\FlashCardAnswer.taskID == taskID)
                .first()
        }
    }
}
