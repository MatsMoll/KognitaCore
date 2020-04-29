import FluentPostgreSQL
import FluentSQL
import Vapor

/// A practice session object
public final class SubjectTest: KognitaPersistenceModel {

    /// The session id
    public var id: Int?

    /// The date when the session was started
    public var createdAt: Date?

    public var updatedAt: Date?

    /// The id of the subject to test
    public var subjectID: Subject.ID

    /// The duratino of the test
    public var duration: TimeInterval

    /// The time the test is open for entering
    public var openedAt: Date?

    /// The date the test ended
    public var endedAt: Date?

    /// The date the test is suppose to be held at
    public var scheduledAt: Date

    /// The password that is needed in order to enter
    public var password: String

    /// A title describing the test
    public var title: String

    /// A bool represening if is in team based learning mode
    public var isTeamBasedLearning: Bool

    public var isOpen: Bool {
        guard
            let openedAt = openedAt,
            let endsAt = endedAt
        else {
            return false
        }
        return openedAt.timeIntervalSinceNow < 0 && endsAt.timeIntervalSinceNow > 0
    }

    init(scheduledAt: Date, duration: TimeInterval, password: String, title: String, subjectID: Subject.ID, isTeamBasedLearning: Bool) {
        self.scheduledAt            = scheduledAt
        self.duration               = duration
        self.password               = password
        self.title                  = title
        self.subjectID              = subjectID
        self.isTeamBasedLearning    = isTeamBasedLearning
    }

    convenience init(data: SubjectTest.Create.Data) {
        self.init(
            scheduledAt: data.scheduledAt,
            duration: data.duration,
            password: data.password,
            title: data.title,
            subjectID: data.subjectID,
            isTeamBasedLearning: data.isTeamBasedLearning
        )
    }

    public func update(with data: Update.Data) -> SubjectTest {
        self.scheduledAt    = data.scheduledAt
        self.duration       = data.duration
        self.password       = data.password
        self.title          = data.title
        self.isTeamBasedLearning = data.isTeamBasedLearning
        return self
    }

    public func open(on conn: DatabaseConnectable) -> EventLoopFuture<SubjectTest> {
        let openDate = Date()
        self.openedAt = openDate
        self.endedAt = openDate.addingTimeInterval(duration)
        return self.save(on: conn)
    }

    public func response(with subject: Subject) throws -> SubjectTest.OverviewResponse {
        try SubjectTest.OverviewResponse(
            test: self,
            subjectName: subject.name,
            subjectID: subject.requireID(),
            hasSubmitted: false,
            testSessionID: nil
        )
    }
}

extension SubjectTest: Content {}
extension SubjectTest: ModelParameterRepresentable {}

extension Date {
    public static var now: Date { Date() }
}
