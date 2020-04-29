import FluentPostgreSQL
import Foundation
import NIO
import Vapor

public final class TaskSessionAnswer: KognitaPersistenceModel {

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

extension TaskSessionAnswer {

    public class DatabaseRepository {
        public static func multipleChoiseAnswers(in sessionID: TaskSession.ID, taskID: Task.ID, on conn: DatabaseConnectable) -> EventLoopFuture<[MultipleChoiseTaskAnswer]> {
            MultipleChoiseTaskAnswer.query(on: conn, withSoftDeleted: true)
                .join(\TaskSessionAnswer.taskAnswerID, to: \MultipleChoiseTaskAnswer.id)
                .join(\MultipleChoiseTaskChoise.id, to: \MultipleChoiseTaskAnswer.choiseID)
                .filter(\TaskSessionAnswer.sessionID == sessionID)
                .filter(\MultipleChoiseTaskChoise.taskId == taskID)
                .all()
        }

        public static func flashCardAnswers(in sessionID: TaskSession.ID, taskID: Task.ID, on conn: DatabaseConnectable) -> EventLoopFuture<FlashCardAnswer?> {
            FlashCardAnswer.query(on: conn)
                .join(\TaskSessionAnswer.taskAnswerID, to: \FlashCardAnswer.id)
                .filter(\TaskSessionAnswer.sessionID == sessionID)
                .filter(\FlashCardAnswer.taskID == taskID)
                .first()
        }
    }
}
