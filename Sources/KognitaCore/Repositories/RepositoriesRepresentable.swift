import Vapor
import FluentKit
import Metrics

/// A protocol defining all the different repositories needed to run the service
public protocol RepositoriesRepresentable {
    /// A topic repository
    var topicRepository: TopicRepository { get }

    /// A subject repository
    var subjectRepository: SubjectRepositoring { get }

    /// A repository handeling subject tests
    var subjectTestRepository: SubjectTestRepositoring { get }

    /// A repository handeling users
    var userRepository: UserRepository { get }

    /// A repository handeling subtopics
    var subtopicRepository: SubtopicRepositoring { get }

    /// A repository handeling test sessions
    var testSessionRepository: TestSessionRepositoring { get }

    /// A repository handeling practice session
    var practiceSessionRepository: PracticeSessionRepository { get }

    /// A repository handleing mutliple choice tasks
    var multipleChoiceTaskRepository: MultipleChoiseTaskRepository { get }

    /// A repository handleing typing tasks
    var typingTaskRepository: TypingTaskRepository { get }

    /// A repository handleing task solutions
    var taskSolutionRepository: TaskSolutionRepositoring { get }

    /// A repository handleing task discussions
    var taskDiscussionRepository: TaskDiscussionRepositoring { get }

    /// A repository handling task results
    var taskResultRepository: TaskResultRepositoring { get }

    /// A repository handeling lecture notes
    var lectureNoteRepository: LectureNoteRepository { get }

    /// A repository handeling note taking
    var lectureNoteTakingRepository: LectureNoteTakingSessionRepository { get }

    /// A repository handeling lecture note recap sessions
    var lectureNoteRecapRepository: LectureNoteRecapSessionRepository { get }

    /// A repository handeling exams
    var examRepository: ExamRepository { get }

    /// A repository handeling exam sessions
    var examSessionRepository: ExamSessionRepository { get }

    /// A repository handeling resources
    var resourceRepository: ResourceRepository { get }

    /// A repository handeling terms
    var termRepository: TermRepository { get }
}

/// A protocol defining how to connect to the different repositories
/// This is using a colosure desing in order to facilitate the possibility of database transactions
protocol AsyncRepositoriesFactory {
    /// Creates the repository given a `Request`
    /// - Parameters:
    ///   - req: The request to use the repository
    ///   - tran: The transaction to run
    func repositories<T>(req: Request, tran: @escaping (RepositoriesRepresentable) -> EventLoopFuture<T>) -> EventLoopFuture<T>

    /// Creates the repository given a `Application`
    /// - Parameters:
    ///   - app: The request to use the repository
    ///   - tran: The transaction to run
    func repositories<T>(app: Application, tran: @escaping (RepositoriesRepresentable) -> EventLoopFuture<T>) -> EventLoopFuture<T>
}

struct RepositoriesFactory {
    var make: AsyncRepositoriesFactory?

    mutating func use(_ make: AsyncRepositoriesFactory) {
        self.make = make
    }
}

extension Application {
    private struct RepositoriesKey: StorageKey {
        typealias Value = RepositoriesFactory
    }

    var repositoriesFactory: RepositoriesFactory {
        get { self.storage[RepositoriesKey.self] ?? .init() }
        set { self.storage[RepositoriesKey.self] = newValue }
    }
}

/// A Provider that sets up the correct `AsyncRepositoriesFactory`
struct DatabaseRepositoriesProvider: LifecycleHandler {
    func willBoot(_ application: Application) throws {
        application.repositoriesFactory.use(DatabaseRepositorieFactory())
    }
}
