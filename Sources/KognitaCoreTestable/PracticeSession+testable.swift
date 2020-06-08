//
//  PracticeSession+testable.swift
//  KognitaCoreTests
//
//  Created by Mats Mollestad on 8/28/19.
//

import Vapor
import FluentPostgreSQL
@testable import KognitaCore

extension PracticeSession {

    /// Creates a `PracticeSession`
    /// - Parameters:
    ///   - subtopicIDs: The subtopic ids the session should handle
    ///   - user: The user owning the session
    ///   - numberOfTaskGoal: A set goal for compleating a number of task
    ///   - conn: The database connection
    /// - Throws: If the database query failes
    /// - Returns: A `TaskSession.PracticeParameter` representing a session
    public static func create(in subtopicIDs: Set<Subtopic.ID>, for user: User, numberOfTaskGoal: Int = 5, on conn: PostgreSQLConnection) throws -> PracticeParameter {

        return try PracticeSession.DatabaseRepository(conn: conn)
            .create(
                from: Create.Data(
                    numberOfTaskGoal: numberOfTaskGoal,
                    subtopicsIDs: subtopicIDs,
                    topicIDs: nil
                ),
                by: user
            )
            .flatMap { session in
                PracticeParameter.resolveParameter("\(session.id)", conn: conn)
        }.wait()
    }
}
