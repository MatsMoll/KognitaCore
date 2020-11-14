//
//  DatabaseRepositories.swift
//  KognitaCore
//
//  Created by Mats Mollestad on 14/11/2020.
//

import Vapor
import FluentKit

/// A representation of different database repositories
/// This will lazely init all the repositories in order to improve performance
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

    /// A password hasher
    var password: PasswordHasher

    /// The database connection to use
    var database: Database

    /// The logger to use
    var logger: Logger

    /// A internal task repository to use
    lazy var taskRepository: TaskRepository = TaskDatabaseModel.DatabaseRepository(database: self.database, taskResultRepository: self.taskResultRepository, userRepository: self.userRepository)

    public lazy var subjectRepository: SubjectRepositoring = Subject.DatabaseRepository(database: database, repositories: self, taskRepository: self.taskRepository)

    public lazy var topicRepository: TopicRepository = Topic.DatabaseRepository(database: database, repositories: self, logger: logger)

    public lazy var subjectTestRepository: SubjectTestRepositoring = SubjectTest.DatabaseRepository(database: database, repositories: self)

    public lazy var userRepository: UserRepository = User.DatabaseRepository(database: database, password: password)

    public lazy var subtopicRepository: SubtopicRepositoring = Subtopic.DatabaseRepository(database: database, userRepository: self.userRepository)

    public lazy var testSessionRepository: TestSessionRepositoring = TestSession.DatabaseRepository(database: database, repositories: self)

    public lazy var practiceSessionRepository: PracticeSessionRepository = PracticeSession.DatabaseRepository(database: database, repositories: self)

    public lazy var multipleChoiceTaskRepository: MultipleChoiseTaskRepository = MultipleChoiceTask.DatabaseRepository(database: database, repositories: self)

    public lazy var typingTaskRepository: TypingTaskRepository = TypingTask.DatabaseRepository(database: database, repositories: self)

    public lazy var taskSolutionRepository: TaskSolutionRepositoring = TaskSolution.DatabaseRepository(database: database, userRepository: self.userRepository)

    public lazy var taskDiscussionRepository: TaskDiscussionRepositoring = TaskDiscussion.DatabaseRepository(database: database)

    public lazy var taskResultRepository: TaskResultRepositoring = TaskResult.DatabaseRepository(database: database)

    public lazy var lectureNoteRepository: LectureNoteRepository = LectureNote.DatabaseRepository(database: database, repositories: self)

    public lazy var lectureNoteTakingRepository: LectureNoteTakingSessionRepository = LectureNote.TakingSession.DatabaseRepository(database: database)

    public lazy var lectureNoteRecapRepository: LectureNoteRecapSessionRepository = LectureNote.RecapSession.DatabaseRepository(database: database, repositories: self)

    public lazy var examRepository: ExamRepository = ExamDatabaseRepository(database: database, repositories: self)

    public lazy var examSessionRepository: ExamSessionRepository = ExamSession.DatabaseRepository(database: database, repositories: self)
}
