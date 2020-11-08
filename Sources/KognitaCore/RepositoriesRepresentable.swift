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
    var lectureNoteRepository: LectureNoteRepository { get }
    var lectureNoteTakingRepository: LectureNoteTakingSessionRepository { get }
    var lectureNoteRecapRepository: LectureNoteRecapSessionRepository { get }
    var examRepository: ExamRepository { get }
    var examSessionRepository: ExamSessionRepository { get }
}

struct DatabaseRepositoriesProvider: LifecycleHandler {
    func willBoot(_ application: Application) throws {
        application.repositoriesFactory.use(DatabaseRepositorieFactory())
    }
}

public class DatabaseRepositories: RepositoriesRepresentable {

    internal init(request: Request) {
        self.database = request.db
        self.password = request.password
        self.logger = request.logger
    }

    internal init(database: Database, password: PasswordHasher, logger: Logger) {
        self.database = database
        self.password = password
        self.logger = logger
    }

    var password: PasswordHasher
    var database: Database
    var logger: Logger

    lazy var taskRepository: TaskRepository = TaskDatabaseModel.DatabaseRepository(database: self.database, taskResultRepository: self.taskResultRepository, userRepository: self.userRepository)

    public lazy var subjectRepository: SubjectRepositoring = Subject.DatabaseRepository(database: database, repositories: self, taskRepository: self.taskRepository)

    public lazy var topicRepository: TopicRepository = Topic.DatabaseRepository(database: database, repositories: self, logger: logger)

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

    public lazy var lectureNoteRepository: LectureNoteRepository = LectureNote.DatabaseRepository(database: database, repositories: self)

    public lazy var lectureNoteTakingRepository: LectureNoteTakingSessionRepository = LectureNote.TakingSession.DatabaseRepository(database: database)

    public lazy var lectureNoteRecapRepository: LectureNoteRecapSessionRepository = LectureNote.RecapSession.DatabaseRepository(database: database, repositories: self)

    public lazy var examRepository: ExamRepository = ExamDatabaseRepository(database: database, repositories: self)

    public lazy var examSessionRepository: ExamSessionRepository = ExamSession.DatabaseRepository(database: database, repositories: self)
}

protocol AsyncRepositoriesFactory {
    func repositories<T>(req: Request, tran: @escaping (RepositoriesRepresentable) -> EventLoopFuture<T>) -> EventLoopFuture<T>
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

extension Request {

    public func repositories<T>(_ transaction: @escaping (RepositoriesRepresentable) -> EventLoopFuture<T>) -> EventLoopFuture<T> {
        self.application.repositoriesFactory.make!.repositories(req: self, tran: transaction)
    }

    public func repositories<T>(_ transaction: @escaping (RepositoriesRepresentable) throws -> EventLoopFuture<T>) -> EventLoopFuture<T> {
        self.application.repositoriesFactory.make!.repositories(req: self) { repo in
            do {
                return try transaction(repo)
            } catch {
                return self.eventLoop.future(error: error)
            }
        }
    }

//    public var repositories: RepositoriesRepresentable {
//        self.application.repositoriesFactory.make!(self)
//    }
}
