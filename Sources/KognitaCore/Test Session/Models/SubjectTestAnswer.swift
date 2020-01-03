import Foundation
import FluentSQL

public final class SubjectTestAnswer: KognitaPersistenceModel {

    public var createdAt: Date?

    public var updatedAt: Date?

    public var id: Int?

    public var taskAnswerID: TaskAnswer.ID

    public var testID: TestSession.ID

    init(testID: TestSession.ID, taskAnswerID: TaskAnswer.ID) {
        self.testID = testID
        self.taskAnswerID = taskAnswerID
    }

    public static func addTableConstraints(to builder: SchemaCreator<SubjectTestAnswer>) {

        builder.unique(on: \.testID, \.taskAnswerID)

        builder.reference(from: \.testID, to: \TestSession.id, onUpdate: .cascade, onDelete: .cascade)
        builder.reference(from: \.taskAnswerID, to: \TaskAnswer.id, onUpdate: .cascade, onDelete: .cascade)
    }
}
