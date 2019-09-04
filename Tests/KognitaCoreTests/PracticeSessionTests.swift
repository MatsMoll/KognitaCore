//
//  PracticeSessionTests.swift
//  App
//
//  Created by Mats Mollestad on 22/01/2019.
//

import Vapor
import XCTest
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
        
        let answer = FlashCardTask.Submit(
            timeUsed: 20,
            knowledge: 3
        )
        let firstResult     = try session.submit(answer, by: user, with: conn).wait()
        let secondResult    = try session.submit(answer, by: user, with: conn).wait()
        let lastResult      = try session.submit(answer, by: user, with: conn).wait()
        
        XCTAssertEqual(firstResult.numberOfCompletedTasks, 1)
        XCTAssertEqual(secondResult.numberOfCompletedTasks, 2)
        XCTAssertEqual(lastResult.numberOfCompletedTasks, 3)
        XCTAssertEqual(firstResult.progress, 20)
        XCTAssertEqual(secondResult.progress, 40)
        XCTAssertEqual(lastResult.progress, 60)
    }
    
    func testNumberOfCompletedTasksMultipleChoice() throws {
        
        let user = try User.create(on: conn)
        
        let subtopic = try Subtopic.create(on: conn)
        
        _ = try MultipleChoiseTask.create(subtopic: subtopic, on: conn)
        _ = try MultipleChoiseTask.create(subtopic: subtopic, on: conn)
        _ = try MultipleChoiseTask.create(subtopic: subtopic, on: conn)
        _ = try MultipleChoiseTask.create(subtopic: subtopic, on: conn)
        
        let session = try PracticeSession.create(in: [subtopic.requireID()], for: user, on: conn)
        
        let answer = MultipleChoiseTask.Submit(
            timeUsed: 20,
            choises: []
        )
        let firstResult     = try session.submit(answer, by: user, with: conn).wait()
        let secondResult    = try session.submit(answer, by: user, with: conn).wait()
        let lastResult      = try session.submit(answer, by: user, with: conn).wait()
        
        XCTAssertEqual(firstResult.numberOfCompletedTasks, 1)
        XCTAssertEqual(secondResult.numberOfCompletedTasks, 2)
        XCTAssertEqual(lastResult.numberOfCompletedTasks, 3)
        XCTAssertEqual(firstResult.progress, 20)
        XCTAssertEqual(secondResult.progress, 40)
        XCTAssertEqual(lastResult.progress, 60)
    }
    
    func testNumberOfCompletedTasksNumberInput() throws {
        
        let user = try User.create(on: conn)
        
        let subtopic = try Subtopic.create(on: conn)
        
        _ = try NumberInputTask.create(subtopic: subtopic, on: conn)
        _ = try NumberInputTask.create(subtopic: subtopic, on: conn)
        _ = try NumberInputTask.create(subtopic: subtopic, on: conn)
        _ = try NumberInputTask.create(subtopic: subtopic, on: conn)
        
        let session = try PracticeSession.create(in: [subtopic.requireID()], for: user, on: conn)
        
        let answer = NumberInputTask.Submit.Data.init(
            timeUsed: 45,
            answer: 0
        )
        
        let firstResult     = try session.submit(answer, by: user, with: conn).wait()
        let secondResult    = try session.submit(answer, by: user, with: conn).wait()
        let lastResult      = try session.submit(answer, by: user, with: conn).wait()
        
        XCTAssertEqual(firstResult.numberOfCompletedTasks, 1)
        XCTAssertEqual(secondResult.numberOfCompletedTasks, 2)
        XCTAssertEqual(lastResult.numberOfCompletedTasks, 3)
        XCTAssertEqual(firstResult.progress, 20)
        XCTAssertEqual(secondResult.progress, 40)
        XCTAssertEqual(lastResult.progress, 60)
    }


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
        ("testPracticeSessionAssignmentMultiple", testPracticeSessionAssignmentMultiple),
        ("testNumberOfCompletedTasksFlashCard", testNumberOfCompletedTasksFlashCard),
        ("testNumberOfCompletedTasksMultipleChoice", testNumberOfCompletedTasksMultipleChoice),
        ("testNumberOfCompletedTasksNumberInput", testNumberOfCompletedTasksNumberInput),
    ]
}
