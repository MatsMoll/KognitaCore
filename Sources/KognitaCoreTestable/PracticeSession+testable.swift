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
    public static func create(in subtopicIDs: Set<Subtopic.ID>, for user: User, numberOfTaskGoal: Int = 5, on conn: PostgreSQLConnection) throws -> TaskSession.PracticeParameter {

        return try PracticeSession
            .create(user, subtopics: subtopicIDs, numberOfTaskGoal: numberOfTaskGoal, on: conn)
            .flatMap { session in
                try TaskSession.find(session.requireID(), on: conn)
                    .unwrap(or: Abort(.internalServerError))
                    .map { taskSession in
                        TaskSession.PracticeParameter(session: taskSession, practiceSession: session)
                }
        }.wait()
    }
}
