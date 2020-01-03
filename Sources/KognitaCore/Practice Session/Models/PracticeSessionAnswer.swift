import FluentPostgreSQL
import Foundation
import NIO

public final class PracticeSessionAnswer: KognitaPersistenceModel {

    public var createdAt: Date?

    public var updatedAt: Date?

    public var id: Int?

    public var sessionID: PracticeSession.ID

    public var taskAnswerID: TaskAnswer.ID

    init(sessionID: PracticeSession.ID, taskAnswerID: TaskAnswer.ID) {
        self.sessionID = sessionID
        self.taskAnswerID = taskAnswerID
    }
}
