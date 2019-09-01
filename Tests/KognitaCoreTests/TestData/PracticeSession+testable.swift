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
    
    static func create(in subtopicIDs: [Subtopic.ID], for user: User, numberOfTaskGoal: Int = 5, on conn: PostgreSQLConnection) throws -> PracticeSession {
        
        return try PracticeSession
            .create(user, subtopics: subtopicIDs, numberOfTaskGoal: numberOfTaskGoal, on: conn)
            .flatMap { session in
                
                try session.assignTask(in: subtopicIDs, on: conn)
                    .flatMap { _ in
                        try session.assignTask(in: subtopicIDs, on: conn)
                            .transform(to: session)
                }
        }.wait()
    }
}
