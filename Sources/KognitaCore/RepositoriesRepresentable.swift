import Vapor

internal protocol RepositoriesRepresentable: Service {
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

    var subjectTestTaskRepository: SubjectTestTaskRepositoring { get }
    var taskRepository: TaskRepository { get }
    var taskSessionAnswerRepository: TaskSessionAnswerRepository { get }
}

public class DatabaseRepositories: RepositoriesRepresentable {

    internal init(conn: DatabaseConnectable) {
        self.conn = conn
    }

    let conn: DatabaseConnectable

    lazy var subjectRepository: SubjectRepositoring = Subject.DatabaseRepository(conn: conn, repositories: self)

    lazy var topicRepository: TopicRepository = Topic.DatabaseRepository(conn: conn, repositories: self)

    lazy var subjectTestRepository: SubjectTestRepositoring = SubjectTest.DatabaseRepository(conn: conn, repositories: self)

    lazy var subjectTestTaskRepository: SubjectTestTaskRepositoring = SubjectTest.Pivot.Task.DatabaseRepository(conn: conn)

    lazy var userRepository: UserRepository = User.DatabaseRepository(conn: conn)

    lazy var subtopicRepository: SubtopicRepositoring = Subtopic.DatabaseRepository(conn: conn)

    lazy var testSessionRepository: TestSessionRepositoring = TestSession.DatabaseRepository(conn: conn, repositories: self)

    lazy var practiceSessionRepository: PracticeSessionRepository = PracticeSession.DatabaseRepository(conn: conn, repositories: self)

    lazy var multipleChoiceTaskRepository: MultipleChoiseTaskRepository = MultipleChoiceTask.DatabaseRepository(conn: conn, repositories: self)

    lazy var typingTaskRepository: FlashCardTaskRepository = FlashCardTask.DatabaseRepository(conn: conn, repositories: self)

    lazy var taskRepository: TaskRepository = Task.DatabaseRepository(conn: conn)

    lazy var taskSolutionRepository: TaskSolutionRepositoring = TaskSolution.DatabaseRepository(conn: conn)

    lazy var taskSessionAnswerRepository: TaskSessionAnswerRepository = TaskSessionAnswer.DatabaseRepository(conn: conn)
}
