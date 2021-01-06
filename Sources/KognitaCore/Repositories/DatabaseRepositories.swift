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
public struct DatabaseRepositories: RepositoriesRepresentable {

    static var metricsTimerLabel: String { "repositories_duration" }
    static var metricsErrorCounterLabel: String { "repositories_errors" }

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
    var taskRepository: TaskRepository { TaskDatabaseModel.DatabaseRepository(database: self.database, taskResultRepository: self.taskResultRepository, userRepository: self.userRepository) }

    public var subjectRepository: SubjectRepositoring { Subject.DatabaseRepository(database: database, repositories: self, taskRepository: self.taskRepository) }

    public var topicRepository: TopicRepository { Topic.DatabaseRepository(database: database, repositories: self, logger: logger) }

    public var subjectTestRepository: SubjectTestRepositoring { SubjectTest.DatabaseRepository(database: database, repositories: self) }

    public var userRepository: UserRepository { User.DatabaseRepository(database: database, password: password) }

    public var subtopicRepository: SubtopicRepositoring { Subtopic.DatabaseRepository(database: database, userRepository: self.userRepository) }

    public var testSessionRepository: TestSessionRepositoring { TestSession.DatabaseRepository(database: database, repositories: self) }

    public var practiceSessionRepository: PracticeSessionRepository { PracticeSession.DatabaseRepository(database: database, repositories: self) }

    public var multipleChoiceTaskRepository: MultipleChoiseTaskRepository { MultipleChoiceTask.DatabaseRepository(database: database, repositories: self) }

    public var typingTaskRepository: TypingTaskRepository { TypingTask.DatabaseRepository(database: database, repositories: self) }

    public var taskSolutionRepository: TaskSolutionRepositoring { TaskSolution.DatabaseRepository(database: database, userRepository: self.userRepository) }

    public var taskDiscussionRepository: TaskDiscussionRepositoring { TaskDiscussion.DatabaseRepository(database: database) }

    public var taskResultRepository: TaskResultRepositoring { TaskResult.DatabaseRepository(database: database, repositories: self) }

    public var lectureNoteRepository: LectureNoteRepository { LectureNote.DatabaseRepository(database: database, repositories: self) }

    public var lectureNoteTakingRepository: LectureNoteTakingSessionRepository { LectureNote.TakingSession.DatabaseRepository(database: database) }

    public var lectureNoteRecapRepository: LectureNoteRecapSessionRepository { LectureNote.RecapSession.DatabaseRepository(database: database, repositories: self) }

    public var examRepository: ExamRepository { ExamDatabaseRepository(database: database, repositories: self) }

    public var examSessionRepository: ExamSessionRepository { ExamSession.DatabaseRepository(database: database, repositories: self) }

    public var resourceRepository: ResourceRepository { DatabaseResourceRepository(database: database) }
}
