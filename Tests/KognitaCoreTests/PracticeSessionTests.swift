//
//  PracticeSessionTests.swift
//  App
//
//  Created by Mats Mollestad on 22/01/2019.
//

import XCTest
@testable import KognitaCore

final class PracticeSessionTests: VaporTestCase {
    
    func testPracticeSessionAssignment() throws {
        
        let user = try User.create(on: conn)
        
        let subtopic = try Subtopic.create(on: conn)
        
        let taskOne = try MultipleChoiseTask.create(subtopic: subtopic, on: conn)
        let taskTwo = try MultipleChoiseTask.create(subtopic: subtopic, on: conn)
        
        let create = try PracticeSession.Create.Data(
            numberOfTaskGoal: 2,
            subtopicsIDs: [
                subtopic.requireID()
            ]
        )
        
        let session = try PracticeSession.repository
            .create(from: create, by: user, on: conn).wait()
        
        let firstTask = try session.currentTask(on: conn).wait()
        
        XCTAssertNotNil(firstTask.1)
        XCTAssert(try firstTask.0.requireID() == taskOne.requireID() || firstTask.0.requireID() == taskTwo.requireID())
        
        let submit = MultipleChoiseTask.Submit(
            timeUsed: 20,
            choises: []
        )
        _ = try PracticeSession.repository
            .submitMultipleChoise(submit, in: session, by: user, on: conn).wait()
        
        let secondTask = try session.currentTask(on: conn).wait()
        
        XCTAssertNotNil(secondTask.1)
        try XCTAssertNotEqual(secondTask.0.requireID(), firstTask.0.requireID())
    }
    
    func testPracticeSessionAssignmentMultiple() throws {
        
        let user = try User.create(on: conn)
        
        let subtopic = try Subtopic.create(on: conn)
        
        let taskOne = try MultipleChoiseTask.create(subtopic: subtopic, on: conn)
        let taskTwo = try MultipleChoiseTask.create(subtopic: subtopic, on: conn)
        
        let create = try PracticeSession.Create.Data(
            numberOfTaskGoal: 2,
            subtopicsIDs: [
                subtopic.requireID()
            ]
        )
        
        _ = try PracticeSession.repository
            .create(from: create, by: user, on: conn).wait()
        let session = try PracticeSession.repository
            .create(from: create, by: user, on: conn).wait()
        
        let firstTask = try session.currentTask(on: conn).wait()
        
        XCTAssertNotNil(firstTask.1)
        XCTAssert(try firstTask.0.requireID() == taskOne.requireID() || firstTask.0.requireID() == taskTwo.requireID())
        
        let submit = MultipleChoiseTask.Submit(
            timeUsed: 20,
            choises: []
        )
        _ = try PracticeSession.repository
            .submitMultipleChoise(submit, in: session, by: user, on: conn).wait()
        
        let secondTask = try session.currentTask(on: conn).wait()
        
        XCTAssertNotNil(secondTask.1)
        try XCTAssertNotEqual(secondTask.0.requireID(), firstTask.0.requireID())
    }

    static let allTests = [
        ("testPracticeSessionAssignment", testPracticeSessionAssignment),
        ("testPracticeSessionAssignmentMultiple", testPracticeSessionAssignmentMultiple)
    ]
}
