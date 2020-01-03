import Foundation
import FluentSQL

public final class SubjectTestAnswer: KognitaPersistenceModel {

    public var createdAt: Date?

    public var updatedAt: Date?

    public var id: Int?

    public var taskAnswerID: TaskAnswer.ID

    public var sessionID: TestSession.ID

    init(sessionID: TestSession.ID, taskAnswerID: TaskAnswer.ID) {
        self.sessionID = sessionID
        self.taskAnswerID = taskAnswerID
    }

    public static func addTableConstraints(to builder: SchemaCreator<SubjectTestAnswer>) {

        builder.unique(on: \.sessionID, \.taskAnswerID)

        builder.reference(from: \.sessionID, to: \TestSession.id, onUpdate: .cascade, onDelete: .cascade)
        builder.reference(from: \.taskAnswerID, to: \TaskAnswer.id, onUpdate: .cascade, onDelete: .cascade)
    }
}
