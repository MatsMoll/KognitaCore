import FluentPostgreSQL
import Foundation
import NIO

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
