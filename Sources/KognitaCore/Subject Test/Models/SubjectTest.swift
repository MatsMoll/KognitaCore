import FluentSQL
import Vapor

extension SubjectTest {
    /// A practice session object
    final class DatabaseModel: KognitaPersistenceModel, KognitaModelUpdatable {

        public static var tableName: String = "SubjectTest"

        /// The session id
        @DBID(custom: "id")
        public var id: Int?

        /// The date when the session was started
        @Timestamp(key: "createdAt", on: .create)
        public var createdAt: Date?

        @Timestamp(key: "updatedAt", on: .update)
        public var updatedAt: Date?

        /// The id of the subject to test
        @Parent(key: "subjectID")
        public var subject: Subject.DatabaseModel

        /// The duratino of the test
        @Field(key: "duration")
        public var duration: TimeInterval

        /// The time the test is open for entering
        @Field(key: "opendAt")
        public var openedAt: Date?

        /// The date the test ended
        @Field(key: "endedAt")
        public var endedAt: Date?

        /// The date the test is suppose to be held at
        @Field(key: "scheduledAt")
        public var scheduledAt: Date

        /// The password that is needed in order to enter
        @Field(key: "password")
        public var password: String

        /// A title describing the test
        @Field(key: "title")
        public var title: String

        /// A bool represening if is in team based learning mode
        @Field(key: "isTeamBasedLearning")
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

        init() { }

        init(scheduledAt: Date, duration: TimeInterval, password: String, title: String, subjectID: Subject.ID, isTeamBasedLearning: Bool) {
            self.scheduledAt            = scheduledAt
            self.duration               = duration
            self.password               = password
            self.title                  = title
            self.$subject.id            = subjectID
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

        func updateValues(with data: Update.Data) throws {
            self.scheduledAt    = data.scheduledAt
            self.duration       = data.duration
            self.password       = data.password
            self.title          = data.title
            self.isTeamBasedLearning = data.isTeamBasedLearning
        }

        public func open(on database: Database) -> EventLoopFuture<SubjectTest.DatabaseModel> {
            let openDate = Date()
            self.openedAt = openDate
            self.endedAt = openDate.addingTimeInterval(duration)
            return self.save(on: database)
                .transform(to: self)
        }

        public func response(with subject: Subject) throws -> SubjectTest.UserOverview {
            try SubjectTest.UserOverview(
                test: self.content(),
                subjectName: subject.name,
                subjectID: subject.id,
                hasSubmitted: false,
                testSessionID: nil
            )
        }
    }
}

extension SubjectTest.DatabaseModel: ContentConvertable {
    func content() throws -> SubjectTest {
        try .init(
            id: requireID(),
            createdAt: createdAt ?? .now,
            subjectID: $subject.id,
            duration: duration,
            openedAt: openedAt,
            endedAt: endedAt,
            scheduledAt: scheduledAt,
            password: password,
            title: title,
            isTeamBasedLearning: isTeamBasedLearning,
            taskIDs: []
        )
    }
}

extension SubjectTest: Content {}
//extension SubjectTest: ModelParameterRepresentable {}

extension Date {
    public static var now: Date { Date() }
}
