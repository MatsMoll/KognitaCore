//
//  PracticeSessionTests.swift
//  App
//
//  Created by Mats Mollestad on 22/01/2019.
//

import Vapor
import XCTest
import FluentPostgreSQL
@testable import KognitaCore

final class PracticeSessionTests: VaporTestCase {
    
    func testNumberOfCompletedTasksFlashCard() throws {
        
        let user = try User.create(on: conn)
        
        let subtopic = try Subtopic.create(on: conn)
        
        _ = try FlashCardTask.create(subtopic: subtopic, on: conn)
        _ = try FlashCardTask.create(subtopic: subtopic, on: conn)
        _ = try FlashCardTask.create(subtopic: subtopic, on: conn)
        _ = try FlashCardTask.create(subtopic: subtopic, on: conn)
    
        let session = try PracticeSession.create(in: [subtopic.requireID()], for: user, on: conn)
        
        let answer = FlashCardTaskSubmit(
            timeUsed: 20,
            knowledge: 3
        )
        let firstResult     = try session.submit(answer, by: user, with: conn).wait()
        let secondResult    = try session.submit(answer, by: user, with: conn).wait()
        let lastResult      = try session.submit(answer, by: user, with: conn).wait()
        
        XCTAssertEqual(firstResult.numberOfCompletedTasks, 1)
        XCTAssertEqual(secondResult.numberOfCompletedTasks, 2)
        XCTAssertEqual(lastResult.numberOfCompletedTasks, 3)
    }
    
    static let allTests = [
        ("testNumberOfCompletedTasksFlashCard", testNumberOfCompletedTasksFlashCard)
    ]
}
