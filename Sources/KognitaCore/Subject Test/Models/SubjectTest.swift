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


    /// The duratino of the test
    public var duration: TimeInterval

    /// The time the test is open for entering
    public var openedAt: Date?

    /// The date the test is suppose to be held at
    public var scheduledAt: Date

    /// The password that is needed in order to enter
    public var password: String

    /// A title describing the test
    public var title: String


    public var isOpen: Bool {
        guard let openedAt = openedAt else {
            return false
        }
        let endsAt = openedAt.addingTimeInterval(abs(duration))
        return openedAt.timeIntervalSinceNow < 0 && endsAt.timeIntervalSinceNow > 0
    }


    init(scheduledAt: Date, duration: TimeInterval, password: String, title: String) {
        self.scheduledAt    = scheduledAt
        self.duration       = duration
        self.password       = password
        self.title          = title
    }

    convenience init(data: SubjectTest.Create.Data) {
        self.init(
            scheduledAt:    data.scheduledAt,
            duration:       data.duration,
            password:       data.password,
            title:          data.title
        )
    }

    public func update(with data: Update.Data) -> SubjectTest {
        self.scheduledAt    = data.scheduledAt
        self.duration       = data.duration
        self.password       = data.password
        self.title          = data.title
        return self
    }

    public func open(on conn: DatabaseConnectable) -> EventLoopFuture<SubjectTest> {
        self.openedAt = .now
        return self.save(on: conn)
    }
}

extension SubjectTest: Content {}
extension SubjectTest: Parameter {}

extension SubjectTest {
    public enum Create {
        public struct Data: Content {
            let tasks: [Task.ID]
            let duration: TimeInterval
            let scheduledAt: Date
            let password: String
            let title: String
        }

        public typealias Response = SubjectTest
    }

    public typealias Update = Create

    public enum Enter {
        public struct Request: Decodable {
            let password: String
        }
    }

    public struct CompletionStatus: Content {
        public internal(set) var amountOfCompletedUsers: Int
        public internal(set) var amountOfEnteredUsers: Int

        public var hasEveryoneCompleted: Bool { amountOfEnteredUsers == amountOfCompletedUsers }
    }

    public struct MultipleChoiseTaskContent: Content {

        public struct Choise: Content {
            let choise: String
            let isCorrect: Bool
            let isSelected: Bool
        }

        public struct TestTask: Content {
            let testTaskID: SubjectTest.Pivot.Task.ID
            let isCurrent: Bool
        }

        public let task: Task
        public let isMultipleSelect: Bool
        public let choises: [Choise]

        public let testTasks: [TestTask]

        init(task: Task, multipleChoiseTask: KognitaCore.MultipleChoiseTask, choises: [MultipleChoiseTaskChoise], selectedChoises: [MultipleChoiseTaskAnswer], testTasks: [SubjectTest.Pivot.Task]) {
            self.task = task
            self.isMultipleSelect = multipleChoiseTask.isMultipleSelect
            self.choises = choises.map { choise in
                Choise(
                    choise: choise.choise,
                    isCorrect: choise.isCorrect,
                    isSelected: selectedChoises.contains(where: { $0.choiseID == choise.id })
                )
            }
            self.testTasks = testTasks.compactMap { testTask in
                guard let taskID = testTask.id else {
                    return nil
                }
                return TestTask(
                    testTaskID: taskID,
                    isCurrent: taskID == task.id
                )
            }
        }
    }

    public struct Results: Content {

        public struct MultipleChoiseTaskResult: Content {

            public struct Choise: Content {
                let choise: String
                let numberOfSubmissions: Int
                let percentage: Double
            }

            let taskID: Task.ID
            let question: String
            let choises: [Choise]
        }

        let title: String
        let heldAt: Date
        let taskResults: [MultipleChoiseTaskResult]
    }
}

extension Date {
    public static var now: Date { Date() }
}
