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

    public var isOpen: Bool { opensAt.timeIntervalSinceNow < 0 && endedAt.timeIntervalSinceNow > 0 }


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