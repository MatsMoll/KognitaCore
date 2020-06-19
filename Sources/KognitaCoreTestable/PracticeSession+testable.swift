//
//  PracticeSession+testable.swift
//  KognitaCoreTests
//
//  Created by Mats Mollestad on 8/28/19.
//

import Vapor
import FluentPostgreSQL
@testable import KognitaCore

public class TestableRepositories: RepositoriesRepresentable {

    public var topicRepository: TopicRepository { repositories.topicRepository }

    public var subjectRepository: SubjectRepositoring { repositories.subjectRepository }

    public var subjectTestRepository: SubjectTestRepositoring { repositories.subjectTestRepository }

    public var userRepository: UserRepository { repositories.userRepository }

    public var subtopicRepository: SubtopicRepositoring { repositories.subtopicRepository }

    public var testSessionRepository: TestSessionRepositoring { repositories.testSessionRepository }

    public var practiceSessionRepository: PracticeSessionRepository { repositories.practiceSessionRepository }

    public var multipleChoiceTaskRepository: MultipleChoiseTaskRepository { repositories.multipleChoiceTaskRepository }

    public var typingTaskRepository: FlashCardTaskRepository { repositories.typingTaskRepository }

    public var taskSolutionRepository: TaskSolutionRepositoring { repositories.taskSolutionRepository }

    public var taskDiscussionRepository: TaskDiscussionRepositoring { repositories.taskDiscussionRepository }

    var repositories: RepositoriesRepresentable

    init(repositories: RepositoriesRepresentable) {
        self.repositories = repositories
    }

    private static var shared: TestableRepositories!
    public static func testable(with conn: DatabaseConnectable) -> TestableRepositories {
        if shared == nil {
            shared = TestableRepositories(repositories: DatabaseRepositories(conn: conn))
        }
        return shared
    }
    public static func reset() {
        shared = nil
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
    public static func create(in subtopicIDs: Set<Subtopic.ID>, for user: User, numberOfTaskGoal: Int = 5, on conn: PostgreSQLConnection) throws -> PracticeSessionRepresentable {

        return try TestableRepositories.testable(with: conn)
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
                PracticeParameter.resolveWith(session.id, conn: conn)
            }
            .wait()
    }
}
