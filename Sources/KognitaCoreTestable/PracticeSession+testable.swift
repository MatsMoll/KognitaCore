//
//  PracticeSession+testable.swift
//  KognitaCoreTests
//
//  Created by Mats Mollestad on 8/28/19.
//

import Vapor
import FluentKit
@testable import KognitaCore

public class TestableRepositories: RepositoriesRepresentable {

    public var topicRepository: TopicRepository

    public var subjectRepository: SubjectRepositoring

    public var subjectTestRepository: SubjectTestRepositoring

    public var userRepository: UserRepository

    public var subtopicRepository: SubtopicRepositoring

    public var testSessionRepository: TestSessionRepositoring

    public var practiceSessionRepository: PracticeSessionRepository

    public var multipleChoiceTaskRepository: MultipleChoiseTaskRepository

    public var typingTaskRepository: FlashCardTaskRepository

    public var taskSolutionRepository: TaskSolutionRepositoring

    public var taskDiscussionRepository: TaskDiscussionRepositoring

    init(repositories: RepositoriesRepresentable) {
        self.topicRepository = repositories.topicRepository
        self.subjectRepository = repositories.subjectRepository
        self.subjectTestRepository = repositories.subjectTestRepository
        self.userRepository = repositories.userRepository
        self.subtopicRepository = repositories.subtopicRepository
        self.testSessionRepository = repositories.testSessionRepository
        self.practiceSessionRepository = repositories.practiceSessionRepository
        self.multipleChoiceTaskRepository = repositories.multipleChoiceTaskRepository
        self.typingTaskRepository = repositories.typingTaskRepository
        self.taskSolutionRepository = repositories.taskSolutionRepository
        self.taskDiscussionRepository = repositories.taskDiscussionRepository
    }

    private static var shared: TestableRepositories!

    public static func testable(with app: Application) -> TestableRepositories {
        testable(database: app.db, password: app.password)
    }

    public static func testable(database: Database, password: PasswordHasher) -> TestableRepositories {
        if shared == nil {
            shared = TestableRepositories(repositories: DatabaseRepositories(database: database, password: password))
        }
        return shared
    }

    public static func reset() {
        shared = nil
    }

    public static func modifyRepositories(_ modifier: @escaping (inout TestableRepositories) -> Void) {
        guard var shared = shared else { fatalError() }
        modifier(&shared)
    }
}

extension PracticeSession {

    /// Creates a `PracticeSession`
    /// - Parameters:
    ///   - subtopicIDs: The subtopic ids the session should handle
    ///   - user: The user owning the session
    ///   - numberOfTaskGoal: A set goal for compleating a number of task
    ///   - conn: The database connection
    /// - Throws: If the database query failes
    /// - Returns: A `TaskSession.PracticeParameter` representing a session
    public static func create(in subtopicIDs: Set<Subtopic.ID>, for user: User, numberOfTaskGoal: Int = 5, on app: Application) throws -> PracticeSessionRepresentable {

        return try TestableRepositories.testable(with: app)
            .practiceSessionRepository
            .create(
                from: Create.Data(
                    numberOfTaskGoal: numberOfTaskGoal,
                    subtopicsIDs: subtopicIDs,
                    topicIDs: nil
                ),
                by: user
            )
            .flatMap { session in
                PracticeParameter.resolveWith(session.id, database: app.db)
            }
            .wait()
    }
}
