import Vapor

public protocol RepositoriesRepresentable: Service {
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

    internal init(conn: DatabaseConnectable) {
        self.conn = conn
    }

    let conn: DatabaseConnectable

    public lazy var subjectRepository: SubjectRepositoring = Subject.DatabaseRepository(conn: conn, repositories: self)

    public lazy var topicRepository: TopicRepository = Topic.DatabaseRepository(conn: conn, repositories: self)

    public lazy var subjectTestRepository: SubjectTestRepositoring = SubjectTest.DatabaseRepository(conn: conn, repositories: self)

    public lazy var userRepository: UserRepository = User.DatabaseRepository(conn: conn)

    public lazy var subtopicRepository: SubtopicRepositoring = Subtopic.DatabaseRepository(conn: conn)

    public lazy var testSessionRepository: TestSessionRepositoring = TestSession.DatabaseRepository(conn: conn, repositories: self)

    public lazy var practiceSessionRepository: PracticeSessionRepository = PracticeSession.DatabaseRepository(conn: conn, repositories: self)

    public lazy var multipleChoiceTaskRepository: MultipleChoiseTaskRepository = MultipleChoiceTask.DatabaseRepository(conn: conn, repositories: self)

    public lazy var typingTaskRepository: FlashCardTaskRepository = FlashCardTask.DatabaseRepository(conn: conn, repositories: self)

    public lazy var taskSolutionRepository: TaskSolutionRepositoring = TaskSolution.DatabaseRepository(conn: conn)

    public lazy var taskDiscussionRepository: TaskDiscussionRepositoring = TaskDiscussion.DatabaseRepository(conn: conn)
}
