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
}

public class DatabaseRepositories: RepositoriesRepresentable {

    internal init(database: Database) {
        self.database = database
    }

    let database: Database

    public lazy var subjectRepository: SubjectRepositoring = Subject.DatabaseRepository(database: database, repositories: self)

    public lazy var topicRepository: TopicRepository = Topic.DatabaseRepository(database: database, repositories: self)

    public lazy var subjectTestRepository: SubjectTestRepositoring = SubjectTest.DatabaseRepository(database: database, repositories: self)

    public lazy var userRepository: UserRepository = User.DatabaseRepository(database: database)

    public lazy var subtopicRepository: SubtopicRepositoring = Subtopic.DatabaseRepository(database: database)

    public lazy var testSessionRepository: TestSessionRepositoring = TestSession.DatabaseRepository(database: database, repositories: self)

    public lazy var practiceSessionRepository: PracticeSessionRepository = PracticeSession.DatabaseRepository(database: database, repositories: self)

    public lazy var multipleChoiceTaskRepository: MultipleChoiseTaskRepository = MultipleChoiceTask.DatabaseRepository(database: database, repositories: self)

    public lazy var typingTaskRepository: FlashCardTaskRepository = FlashCardTask.DatabaseRepository(database: database, repositories: self)

    public lazy var taskSolutionRepository: TaskSolutionRepositoring = TaskSolution.DatabaseRepository(database: database)

    public lazy var taskDiscussionRepository: TaskDiscussionRepositoring = TaskDiscussion.DatabaseRepository(database: database)
}
