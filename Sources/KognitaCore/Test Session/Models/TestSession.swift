import Foundation

public final class TestSession: KognitaPersistenceModel {

    public var createdAt: Date?

    public var updatedAt: Date?

    public var id: Int?

    public var testID: SubjectTest.ID

    public var userID: User.ID

    init(testID: SubjectTest.ID, userID: User.ID) {
        self.testID = testID
        self.userID = userID
    }
}
