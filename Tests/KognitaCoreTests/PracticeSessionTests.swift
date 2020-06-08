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

    lazy var practiceSessionRepository: some PracticeSessionRepository = { PracticeSession.DatabaseRepository(conn: conn) }()
    lazy var multipleChoiceRepository: some MultipleChoiseTaskRepository = { MultipleChoiceTask.DatabaseRepository(conn: conn) }()

    func testUpdateFlashAnswer() {
        failableTest {

            let user = try User.create(on: conn)

            let subtopic = try Subtopic.create(on: conn)

            _ = try FlashCardTask.create(subtopic: subtopic, on: conn)
            _ = try FlashCardTask.create(subtopic: subtopic, on: conn)
            _ = try FlashCardTask.create(subtopic: subtopic, on: conn)
            _ = try FlashCardTask.create(subtopic: subtopic, on: conn)

            let session = try PracticeSession.create(in: [subtopic.id], for: user, on: conn)

            var answer = FlashCardTask.Submit(
                timeUsed: 20,
                knowledge: 3,
                taskIndex: 1,
                answer: ""
            )
            let updatedAnswer = FlashCardTask.Submit(
                timeUsed: 20,
                knowledge: 4,
                taskIndex: 2,
                answer: ""
            )

            _ = try practiceSessionRepository.submit(answer, in: session, by: user).wait()
            answer.taskIndex = 2
            _ = try practiceSessionRepository.submit(answer, in: session, by: user).wait()
            _ = try practiceSessionRepository.submit(updatedAnswer, in: session, by: user).wait()
        }
    }

    func testUnverifiedEmailPractice() throws {

        let user = try User.create(on: conn)
        let unverifiedUser = try User.create(isAdmin: false, isEmailVerified: false, on: conn)

        let subtopic = try Subtopic.create(on: conn)

        _ = try FlashCardTask.create(subtopic: subtopic, on: conn)
        _ = try FlashCardTask.create(subtopic: subtopic, on: conn)
        _ = try FlashCardTask.create(subtopic: subtopic, on: conn)
        _ = try FlashCardTask.create(subtopic: subtopic, on: conn)

        let createSession = PracticeSession.Create.Data(
            numberOfTaskGoal: 2,
            subtopicsIDs: [subtopic.id],
            topicIDs: nil
        )

        XCTAssertNoThrow(
            try practiceSessionRepository.create(from: createSession, by: user).wait()
        )
        XCTAssertThrowsError(
            try practiceSessionRepository.create(from: createSession, by: nil).wait()
        )
        XCTAssertThrowsError(
            try practiceSessionRepository.create(from: createSession, by: unverifiedUser).wait()
        )
    }

    func testNumberOfCompletedTasksFlashCard() throws {

        let user = try User.create(on: conn)

        let subtopic = try Subtopic.create(on: conn)

        _ = try FlashCardTask.create(subtopic: subtopic, on: conn)
        _ = try FlashCardTask.create(subtopic: subtopic, on: conn)
        _ = try FlashCardTask.create(subtopic: subtopic, on: conn)
        _ = try FlashCardTask.create(subtopic: subtopic, on: conn)

        let session = try PracticeSession.create(in: [subtopic.id], for: user, on: conn)

        var answer = FlashCardTask.Submit(
            timeUsed: 20,
            knowledge: 3,
            taskIndex: 1,
            answer: ""
        )
        let firstResult     = try practiceSessionRepository.submit(answer, in: session, by: user).wait()
        answer.taskIndex = 2
        let secondResult    = try practiceSessionRepository.submit(answer, in: session, by: user).wait()
        answer.taskIndex = 3
        let lastResult      = try practiceSessionRepository.submit(answer, in: session, by: user).wait()

        XCTAssertEqual(firstResult.progress, 20)
        XCTAssertEqual(secondResult.progress, 40)
        XCTAssertEqual(lastResult.progress, 60)
    }

    func testNumberOfCompletedTasksMultipleChoice() throws {

        let user = try User.create(on: conn)

        let subtopic = try Subtopic.create(on: conn)

        _ = try MultipleChoiceTask.create(subtopic: subtopic, on: conn)
        _ = try MultipleChoiceTask.create(subtopic: subtopic, on: conn)
        _ = try MultipleChoiceTask.create(subtopic: subtopic, on: conn)
        _ = try MultipleChoiceTask.create(subtopic: subtopic, on: conn)

        let session = try PracticeSession.create(in: [subtopic.id], for: user, on: conn)

        var answer = MultipleChoiceTask.Submit(
            timeUsed: 20,
            choises: [],
            taskIndex: 1
        )
        let firstResult     = try practiceSessionRepository.submit(answer, in: session, by: user).wait()
        answer.taskIndex = 2
        let secondResult    = try practiceSessionRepository.submit(answer, in: session, by: user).wait()
        answer.taskIndex = 3
        let lastResult      = try practiceSessionRepository.submit(answer, in: session, by: user).wait()

        XCTAssertEqual(firstResult.progress, 20)
        XCTAssertEqual(secondResult.progress, 40)
        XCTAssertEqual(lastResult.progress, 60)
    }

    func testPracticeSessionAssignment() throws {
        do {
            let user = try User.create(on: conn)

            let subtopic = try Subtopic.create(on: conn)

            let taskOne = try MultipleChoiceTask.create(subtopic: subtopic, on: conn)
            let taskTwo = try MultipleChoiceTask.create(subtopic: subtopic, on: conn)

            let create = PracticeSession.Create.Data(
                numberOfTaskGoal: 2,
                subtopicsIDs: [subtopic.id],
                topicIDs: nil
            )

            let session = try practiceSessionRepository.create(from: create, by: user).wait()
            let representable = try session.representable(on: conn).wait()

            let firstTask = try practiceSessionRepository.currentActiveTask(in: session).wait()

            XCTAssertNotNil(firstTask.multipleChoise)
            XCTAssert(try firstTask.task.requireID() == taskOne.id || firstTask.task.requireID() == taskTwo.id)

            let firstChoises = try choisesAt(index: 1, for: representable).filter({ $0.isCorrect })
            let submit = MultipleChoiceTask.Submit(
                timeUsed: 20,
                choises: firstChoises.compactMap { $0.id },
                taskIndex: 1
            )
            _ = try practiceSessionRepository.submit(submit, in: representable, by: user).wait()
            XCTAssertEqual(try MultipleChoiseTaskAnswer.query(on: conn).count().wait(), 1)
            XCTAssertEqual(try TaskSessionAnswer.query(on: conn).count().wait(), 1)

            let secondTask = try practiceSessionRepository.currentActiveTask(in: session).wait()

            XCTAssertNotNil(secondTask.multipleChoise)
            try XCTAssertNotEqual(secondTask.task.requireID(), firstTask.task.requireID())

            let secondChoises = try choisesAt(index: 2, for: representable).first!
            let secondSubmit = try MultipleChoiceTask.Submit(
                timeUsed: 20,
                choises: [secondChoises.requireID()],
                taskIndex: 2
            )
            _ = try practiceSessionRepository.submit(secondSubmit, in: representable, by: user).wait()
            _ = try practiceSessionRepository.end(representable, for: user).wait()

            XCTAssertEqual(try MultipleChoiseTaskAnswer.query(on: conn).count().wait(), 2)
            XCTAssertEqual(try TaskSessionAnswer.query(on: conn).count().wait(), 2)
            XCTAssertNotNil(representable.endedAt)

        } catch {
            XCTFail(error.localizedDescription)
        }
    }

    func testPracticeSessionAssignmentWithTestTasks() throws {
        do {
            let user = try User.create(on: conn)

            let subtopic = try Subtopic.create(on: conn)

            _ = try MultipleChoiceTask.create(subtopic: subtopic, on: conn)
            _ = try MultipleChoiceTask.create(subtopic: subtopic, on: conn)
            let taskThree = try MultipleChoiceTask.create(subtopic: subtopic, on: conn)
            let testTask = try Task.create(subtopic: subtopic, isTestable: true, on: conn)

            _ = try multipleChoiceRepository.delete(model: taskThree, by: user).wait()

            let create = PracticeSession.Create.Data(
                numberOfTaskGoal: 2,
                subtopicsIDs: [subtopic.id],
                topicIDs: nil
            )

            let session = try practiceSessionRepository.create(from: create, by: user).wait()
            let representable = try session.representable(on: conn).wait()

            let firstTask = try practiceSessionRepository.currentActiveTask(in: session).wait()

            XCTAssertNotNil(firstTask.multipleChoise)
            XCTAssert(try firstTask.task.requireID() != testTask.requireID())

            let submit = MultipleChoiceTask.Submit(
                timeUsed: 20,
                choises: [],
                taskIndex: 1
            )
            _ = try practiceSessionRepository.submit(submit, in: representable, by: user).wait()

            let secondTask = try practiceSessionRepository.currentActiveTask(in: session).wait()

            XCTAssertNotNil(secondTask.multipleChoise)
            XCTAssert(try secondTask.task.requireID() != testTask.requireID())

            let secondSubmit = MultipleChoiceTask.Submit(
                timeUsed: 20,
                choises: [],
                taskIndex: 2
            )
            _ = try practiceSessionRepository.submit(secondSubmit, in: representable, by: user).wait()
            let thiredTask = try practiceSessionRepository.currentActiveTask(in: session).wait()

            XCTAssert(try thiredTask.task.requireID() != testTask.requireID())

        } catch {
            XCTFail(error.localizedDescription)
        }
    }

    func testPracticeSessionAssignmentWithoutPracticeCapability() throws {

        let user = try User.create(isAdmin: false, on: conn)

        let subtopic = try Subtopic.create(on: conn)

        _ = try MultipleChoiceTask.create(subtopic: subtopic, on: conn)
        _ = try MultipleChoiceTask.create(subtopic: subtopic, on: conn)

        let create = PracticeSession.Create.Data(
            numberOfTaskGoal: 2,
            subtopicsIDs: [subtopic.id],
            topicIDs: nil
        )

        XCTAssertThrowsError(
            try practiceSessionRepository
                .create(from: create, by: user).wait()
        )
        XCTAssertEqual(try PracticeSession.DatabaseModel.query(on: conn).count().wait(), 0)
    }

    func testPracticeSessionAssignmentMultiple() throws {

        let user = try User.create(on: conn)

        let subtopic = try Subtopic.create(on: conn)

        let taskOne = try MultipleChoiceTask.create(subtopic: subtopic, on: conn)
        let taskTwo = try MultipleChoiceTask.create(subtopic: subtopic, on: conn)

        let create = PracticeSession.Create.Data(
            numberOfTaskGoal: 2,
            subtopicsIDs: [subtopic.id],
            topicIDs: nil
        )

        _ = try practiceSessionRepository.create(from: create, by: user).wait()
        let session = try practiceSessionRepository.create(from: create, by: user).wait()
        let representable = try session.representable(on: conn).wait()

        let firstTask = try practiceSessionRepository.currentActiveTask(in: session).wait()

        XCTAssertNotNil(firstTask.multipleChoise)
        XCTAssert(try firstTask.task.requireID() == taskOne.id || firstTask.task.requireID() == taskTwo.id)

        let submit = MultipleChoiceTask.Submit(
            timeUsed: 20,
            choises: [],
            taskIndex: 1
        )
        _ = try practiceSessionRepository
            .submit(submit, in: representable, by: user).wait()

        let secondTask = try practiceSessionRepository.currentActiveTask(in: session).wait()

        XCTAssertNotNil(secondTask.multipleChoise)
        try XCTAssertNotEqual(secondTask.task.requireID(), firstTask.task.requireID())
    }

    func testAsignTaskWithTaskResult() throws {

        let user = try User.create(on: conn)

        let subtopic = try Subtopic.create(on: conn)

        _ = try MultipleChoiceTask.create(subtopic: subtopic, on: conn)
        _ = try MultipleChoiceTask.create(subtopic: subtopic, on: conn)
        _ = try MultipleChoiceTask.create(on: conn)

        let create = PracticeSession.Create.Data(
            numberOfTaskGoal: 2,
            subtopicsIDs: [subtopic.id],
            topicIDs: nil
        )

        let firstSession = try practiceSessionRepository.create(from: create, by: user).wait()
        let secondSession = try practiceSessionRepository.create(from: create, by: user).wait()

        let firstRepresentable = try firstSession.representable(on: conn).wait()
        let secondRepresentable = try secondSession.representable(on: conn).wait()

        var submit = MultipleChoiceTask.Submit(
            timeUsed: 20,
            choises: [],
            taskIndex: 1

        )
        do {
            _ = try practiceSessionRepository.submit(submit, in: firstRepresentable, by: user).wait()
            submit.taskIndex = 2
            _ = try practiceSessionRepository.submit(submit, in: firstRepresentable, by: user).wait()

            submit.taskIndex = 1
            _ = try practiceSessionRepository.submit(submit, in: secondRepresentable, by: user).wait()
            submit.taskIndex = 2
            _ = try practiceSessionRepository.submit(submit, in: secondRepresentable, by: user).wait()
            submit.taskIndex = 3
            XCTAssertThrowsError(
                _ = try practiceSessionRepository.submit(submit, in: secondRepresentable, by: user).wait()
            )
        } catch {
            XCTFail(error.localizedDescription)
        }
    }

    func testTaskSessionPracticeParameter() throws {

        let user = try User.create(on: conn)

        let subtopic = try Subtopic.create(on: conn)

        _ = try MultipleChoiceTask.create(subtopic: subtopic, on: conn)
        _ = try MultipleChoiceTask.create(subtopic: subtopic, on: conn)
        _ = try MultipleChoiceTask.create(on: conn)
        let createdSesssion = try PracticeSession.create(in: [subtopic.id], for: user, on: conn)

        let parameterSession = try PracticeSession.PracticeParameter.resolveParameter("\(createdSesssion.requireID())", conn: conn).wait()

        XCTAssertEqual(createdSesssion.practiceSession.id, parameterSession.practiceSession.id)
        XCTAssertEqual(createdSesssion.practiceSession.createdAt, parameterSession.practiceSession.createdAt)
        XCTAssertEqual(createdSesssion.practiceSession.id, parameterSession.session.id)
    }

    func testExtendSession() {
        failableTest {

            let user = try User.create(on: conn)

            let subtopic = try Subtopic.create(on: conn)

            _ = try MultipleChoiceTask.create(subtopic: subtopic, on: conn)
            _ = try MultipleChoiceTask.create(subtopic: subtopic, on: conn)
            _ = try MultipleChoiceTask.create(on: conn)
            let createdSesssion = try PracticeSession.create(in: [subtopic.id], for: user, numberOfTaskGoal: 10, on: conn)

            let parameterSession = try PracticeSession.PracticeParameter.resolveParameter("\(createdSesssion.requireID())", conn: conn).wait()

            XCTAssertEqual(parameterSession.numberOfTaskGoal, 10)
            try practiceSessionRepository.extend(session: parameterSession, for: user).wait()
            XCTAssertEqual(parameterSession.numberOfTaskGoal, 15)
        }
    }

    func choisesAt(index: Int, for session: PracticeSessionRepresentable) throws -> [MultipleChoiseTaskChoise] {
        try PracticeSession.Pivot.Task.query(on: conn)
            .filter(\PracticeSession.Pivot.Task.sessionID, .equal, session.requireID())
            .filter(\.index, .equal, index)
            .join(\MultipleChoiseTaskChoise.taskId, to: \PracticeSession.Pivot.Task.taskID)
            .decode(MultipleChoiseTaskChoise.self)
            .all()
            .wait()
    }

    static let allTests = [
        ("testUpdateFlashAnswer", testUpdateFlashAnswer),
        ("testPracticeSessionAssignment", testPracticeSessionAssignment),
        ("testPracticeSessionAssignmentWithoutPracticeCapability", testPracticeSessionAssignmentWithoutPracticeCapability),
        ("testPracticeSessionAssignmentMultiple", testPracticeSessionAssignmentMultiple),
        ("testNumberOfCompletedTasksFlashCard", testNumberOfCompletedTasksFlashCard),
        ("testNumberOfCompletedTasksMultipleChoice", testNumberOfCompletedTasksMultipleChoice),
        ("testAsignTaskWithTaskResult", testAsignTaskWithTaskResult),
        ("testPracticeSessionAssignmentWithTestTasks", testPracticeSessionAssignmentWithTestTasks),
        ("testExtendSession", testExtendSession)
    ]
}
