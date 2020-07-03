import Vapor
import FluentKit

public protocol RepositoriesRepresentable {
    var topicRepository: TopicRepository { get }
    var subjectRepository: SubjectRepositoring { get }
    var subjectTestRepository: SubjectTestRepositoring { get }
    var userRepository: UserRepository { get }
    var subtopicRepository: SubtopicRepositoring { get }
    var testSessionRepository: TestSessionRepositoring { get }
    var practiceSessionRepository: PracticeSessionRepository { get }
    var multipleChoiceTaskRepository: MultipleChoiseTaskRepository { get }
    var typingTaskRepository: FlashCardTaskRepository { get }
    var taskSolutionRepository: TaskSolutionRepositoring { get }
    var taskDiscussionRepository: TaskDiscussionRepositoring { get }
    var taskResultRepository: TaskResultRepositoring { get }
}

struct DatabaseRepositoriesProvider: LifecycleHandler {
    func willBoot(_ application: Application) throws {
        application.repositoriesFactory.use(DatabaseRepositories.init)
    }
}

public class DatabaseRepositories: RepositoriesRepresentable {

    internal init(request: Request) {
        self.database = request.db
        self.password = request.password
    }

    internal init(database: Database, password: PasswordHasher) {
        self.database = database
        self.password = password
    }

    var password: PasswordHasher
    var database: Database

    public lazy var subjectRepository: SubjectRepositoring = Subject.DatabaseRepository(database: database, repositories: self)

    public lazy var topicRepository: TopicRepository = Topic.DatabaseRepository(database: database, repositories: self)

    public lazy var subjectTestRepository: SubjectTestRepositoring = SubjectTest.DatabaseRepository(database: database, repositories: self)

    public lazy var userRepository: UserRepository = User.DatabaseRepository(database: database, password: password)

    public lazy var subtopicRepository: SubtopicRepositoring = Subtopic.DatabaseRepository(database: database, userRepository: self.userRepository)

    public lazy var testSessionRepository: TestSessionRepositoring = TestSession.DatabaseRepository(database: database, repositories: self)

    public lazy var practiceSessionRepository: PracticeSessionRepository = PracticeSession.DatabaseRepository(database: database, repositories: self)

    public lazy var multipleChoiceTaskRepository: MultipleChoiseTaskRepository = MultipleChoiceTask.DatabaseRepository(database: database, repositories: self)

    public lazy var typingTaskRepository: FlashCardTaskRepository = FlashCardTask.DatabaseRepository(database: database, repositories: self)

    public lazy var taskSolutionRepository: TaskSolutionRepositoring = TaskSolution.DatabaseRepository(database: database, userRepository: self.userRepository)

    public lazy var taskDiscussionRepository: TaskDiscussionRepositoring = TaskDiscussion.DatabaseRepository(database: database)

    public lazy var taskResultRepository: TaskResultRepositoring = TaskResult.DatabaseRepository(database: database)
}

struct RepositoriesFactory {
    var make: ((Request) -> RepositoriesRepresentable)?

    mutating func use(_ make: @escaping ((Request) -> RepositoriesRepresentable)) {
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

extension Request {
    public var repositories: RepositoriesRepresentable {
        self.application.repositoriesFactory.make!(self)
    }
}
