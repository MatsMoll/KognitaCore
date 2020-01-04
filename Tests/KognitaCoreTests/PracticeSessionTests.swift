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

    func testIncorrectTaskIndex() throws {

        let user = try User.create(on: conn)

        let subtopic = try Subtopic.create(on: conn)

        _ = try FlashCardTask.create(subtopic: subtopic, on: conn)
        _ = try FlashCardTask.create(subtopic: subtopic, on: conn)
        _ = try FlashCardTask.create(subtopic: subtopic, on: conn)
        _ = try FlashCardTask.create(subtopic: subtopic, on: conn)

        let session = try PracticeSession.create(in: [subtopic.requireID()], for: user, on: conn)

        var answer = FlashCardTask.Submit(
            timeUsed: 20,
            knowledge: 3,
            taskIndex: 1,
            answer: ""
        )

        XCTAssertNoThrow(try PracticeSession.DatabaseRepository.submit(answer, in: session, by: user, on: conn).wait())
        answer.taskIndex = 2
        XCTAssertNoThrow(try PracticeSession.DatabaseRepository.submit(answer, in: session, by: user, on: conn).wait())
        answer.taskIndex = 2
        XCTAssertThrowsError(try PracticeSession.DatabaseRepository.submit(answer, in: session, by: user, on: conn).wait())
    }

    func testNumberOfCompletedTasksFlashCard() throws {

        let user = try User.create(on: conn)

        let subtopic = try Subtopic.create(on: conn)

        _ = try FlashCardTask.create(subtopic: subtopic, on: conn)
        _ = try FlashCardTask.create(subtopic: subtopic, on: conn)
        _ = try FlashCardTask.create(subtopic: subtopic, on: conn)
        _ = try FlashCardTask.create(subtopic: subtopic, on: conn)
        
        let session = try PracticeSession.create(in: [subtopic.requireID()], for: user, on: conn)
        
        var answer = FlashCardTask.Submit(
            timeUsed: 20,
            knowledge: 3,
            taskIndex: 1,
            answer: ""
        )
        let firstResult     = try PracticeSession.DatabaseRepository.submit(answer, in: session, by: user, on: conn).wait()
        answer.taskIndex = 2
        let secondResult    = try PracticeSession.DatabaseRepository.submit(answer, in: session, by: user, on: conn).wait()
        answer.taskIndex = 3
        let lastResult      = try PracticeSession.DatabaseRepository.submit(answer, in: session, by: user, on: conn).wait()

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
        
        var answer = MultipleChoiseTask.Submit(
            timeUsed: 20,
            choises: [],
            taskIndex: 1
        )
        let firstResult     = try PracticeSession.DatabaseRepository.submit(answer, in: session, by: user, on: conn).wait()
        answer.taskIndex = 2
        let secondResult    = try PracticeSession.DatabaseRepository.submit(answer, in: session, by: user, on: conn).wait()
        answer.taskIndex = 3
        let lastResult      = try PracticeSession.DatabaseRepository.submit(answer, in: session, by: user, on: conn).wait()
        
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
            ],
            topicIDs: nil
        )
        
        let session = try PracticeSession.DatabaseRepository
            .create(from: create, by: user, on: conn).wait()
        let representable = try session.representable(on: conn).wait()
        
        let firstTask = try session.currentTask(on: conn).wait()

        XCTAssertNotNil(firstTask.multipleChoise)
        XCTAssert(try firstTask.task.requireID() == taskOne.requireID() || firstTask.task.requireID() == taskTwo.requireID())
        
        let submit = MultipleChoiseTask.Submit(
            timeUsed: 20,
            choises: [],
            taskIndex: 1
        )
        _ = try PracticeSession.DatabaseRepository
            .submit(submit, in: representable, by: user, on: conn).wait()
        
        let secondTask = try session.currentTask(on: conn).wait()
        
        XCTAssertNotNil(secondTask.multipleChoise)
        try XCTAssertNotEqual(secondTask.task.requireID(), firstTask.task.requireID())
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
            ],
            topicIDs: nil
        )
        
        _ = try PracticeSession.DatabaseRepository
            .create(from: create, by: user, on: conn).wait()
        let session = try PracticeSession.DatabaseRepository
            .create(from: create, by: user, on: conn).wait()
        let representable = try session.representable(on: conn).wait()
        
        let firstTask = try session.currentTask(on: conn).wait()
        
        XCTAssertNotNil(firstTask.multipleChoise)
        XCTAssert(try firstTask.task.requireID() == taskOne.requireID() || firstTask.task.requireID() == taskTwo.requireID())
        
        let submit = MultipleChoiseTask.Submit(
            timeUsed: 20,
            choises: [],
            taskIndex: 1
        )
        _ = try PracticeSession.DatabaseRepository
            .submit(submit, in: representable, by: user, on: conn).wait()
        
        let secondTask = try session.currentTask(on: conn).wait()
        
        XCTAssertNotNil(secondTask.multipleChoise)
        try XCTAssertNotEqual(secondTask.task.requireID(), firstTask.task.requireID())
    }

    func testAsignTaskWithTaskResult() throws {

        let user = try User.create(on: conn)

        let subtopic = try Subtopic.create(on: conn)

        _ = try MultipleChoiseTask.create(subtopic: subtopic, on: conn)
        _ = try MultipleChoiseTask.create(subtopic: subtopic, on: conn)
        _ = try MultipleChoiseTask.create(on: conn)

        let create = try PracticeSession.Create.Data(
            numberOfTaskGoal: 2,
            subtopicsIDs: [
                subtopic.requireID()
            ],
            topicIDs: nil
        )

        let firstSession = try PracticeSession.DatabaseRepository
            .create(from: create, by: user, on: conn).wait()
        let secondSession = try PracticeSession.DatabaseRepository
            .create(from: create, by: user, on: conn).wait()

        let firstRepresentable = try firstSession.representable(on: conn).wait()
        let secondRepresentable = try secondSession.representable(on: conn).wait()

        var submit = MultipleChoiseTask.Submit(
            timeUsed: 20,
            choises: [],
            taskIndex: 1
            
        )
        do {
            _ = try PracticeSession.DatabaseRepository
                .submit(submit, in: firstRepresentable, by: user, on: conn).wait()
            submit.taskIndex = 2
            _ = try PracticeSession.DatabaseRepository
                .submit(submit, in: firstRepresentable, by: user, on: conn).wait()

            submit.taskIndex = 1
            _ = try PracticeSession.DatabaseRepository
                .submit(submit, in: secondRepresentable, by: user, on: conn).wait()
            submit.taskIndex = 2
            _ = try PracticeSession.DatabaseRepository
                .submit(submit, in: secondRepresentable, by: user, on: conn).wait()
            submit.taskIndex = 3
            XCTAssertThrowsError(
                _ = try PracticeSession.DatabaseRepository
                    .submit(submit, in: secondRepresentable, by: user, on: conn).wait()
            )
        } catch {
            XCTFail(error.localizedDescription)
        }

    }

    func testTaskSessionPracticeParameter() throws {

        let user = try User.create(on: conn)

        let subtopic = try Subtopic.create(on: conn)

        _ = try MultipleChoiseTask.create(subtopic: subtopic, on: conn)
        _ = try MultipleChoiseTask.create(subtopic: subtopic, on: conn)
        _ = try MultipleChoiseTask.create(on: conn)
        let createdSesssion = try PracticeSession.create(in: [subtopic.requireID()], for: user, on: conn)

        let parameterSession = try TaskSession.PracticeParameter.resolveParameter("\(createdSesssion.requireID())", on: app).wait()

        XCTAssertEqual(createdSesssion.practiceSession.id,          parameterSession.practiceSession.id)
        XCTAssertEqual(createdSesssion.practiceSession.createdAt,   parameterSession.practiceSession.createdAt)
        XCTAssertEqual(createdSesssion.practiceSession.id,          parameterSession.session.id)
    }

    static let allTests = [
        ("testIncorrectTaskIndex", testIncorrectTaskIndex),
        ("testPracticeSessionAssignment", testPracticeSessionAssignment),
        ("testPracticeSessionAssignmentMultiple", testPracticeSessionAssignmentMultiple),
        ("testNumberOfCompletedTasksFlashCard", testNumberOfCompletedTasksFlashCard),
        ("testNumberOfCompletedTasksMultipleChoice", testNumberOfCompletedTasksMultipleChoice),
        ("testAsignTaskWithTaskResult", testAsignTaskWithTaskResult)
    ]
}
