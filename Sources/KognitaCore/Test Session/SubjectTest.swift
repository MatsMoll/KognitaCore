import FluentPostgreSQL
import FluentSQL
import Vapor

/// A practice session object
public final class SubjectTest: KognitaPersistenceModel {

    /// The session id
    public var id: Int?

    /// The date the session was ended
    public private(set) var endedAt: Date

    /// The time the test is possible to start
    public var opensAt: Date

    /// The date when the session was started
    public var createdAt: Date?

    public var updatedAt: Date?


    init(opensAt: Date, duration: TimeInterval) {
        self.opensAt = opensAt
        self.endedAt = opensAt.addingTimeInterval(abs(duration))
    }

    convenience init(data: SubjectTest.Create.Data) {
        self.init(opensAt: data.opensAt, duration: data.duration)
    }

    public func update(duration: TimeInterval) {
        self.endedAt = opensAt.addingTimeInterval(abs(duration))
    }

    public func update(with content: Update.Data) -> SubjectTest {
        self.opensAt = content.opensAt
        self.update(duration: content.duration)
        return self
    }

    public static var deletedAtKey: WritableKeyPath<SubjectTest, Date>? = \.endedAt
}


extension SubjectTest {
    public enum Create {
        public struct Data: Decodable {
            let tasks: [Task.ID]
            let duration: TimeInterval
            let opensAt: Date
        }

        public typealias Response = SubjectTest
    }

    public typealias Update = Create
}


public protocol SubjectTestRepositoring:
    CreateModelRepository,
    UpdateModelRepository
    where
    CreateData      == SubjectTest.Create.Data,
    CreateResponse  == SubjectTest.Create.Response,
    UpdateData      == SubjectTest.Create.Data,
    UpdateResponse  == SubjectTest.Create.Response,
    Model           == SubjectTest
{}


extension SubjectTest {

    @available(OSX 10.15, *)
    struct Repository: SubjectTestRepositoring {

        static func create(from content: SubjectTest.Create.Data, by user: User?, on conn: DatabaseConnectable) throws -> EventLoopFuture<SubjectTest> {
            guard let user = user else {
                throw Abort(.unauthorized)
            }
            guard user.isCreator else {
                throw Abort(.forbidden)
            }
            return SubjectTest(data: content)
                .create(on: conn)
                .flatMap { test in
                    try SubjectTest.Pivot.Task.Repository
                        .create(
                            from: .init(
                                testID: test.requireID(),
                                taskIDs: content.tasks
                            ),
                            by: user,
                            on: conn
                    )
                    .transform(to: test)
            }
        }

        static func update(model: SubjectTest, to data: SubjectTest.Update.Data, by user: User, on conn: DatabaseConnectable) throws -> EventLoopFuture<SubjectTest> {
            guard user.isCreator else {
                throw Abort(.forbidden)
            }
            return model.update(with: data)
                .save(on: conn)
                .flatMap { test in
                    try SubjectTest.Pivot.Task
                        .Repository
                        .update(
                            model: test,
                            to: data.tasks,
                            by: user,
                            on: conn
                    )
                    .transform(to: test)
            }
        }
    }
}
