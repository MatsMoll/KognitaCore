//
//  PracticeSessionTests.swift
//  App
//
//  Created by Mats Mollestad on 22/01/2019.
//

import Vapor
import XCTest
@testable import KognitaCore
import KognitaCoreTestable

final class PracticeSessionTests: VaporTestCase {

    lazy var practiceSessionRepository: PracticeSessionRepository = { TestableRepositories.testable(with: database).practiceSessionRepository }()
    lazy var multipleChoiceRepository: MultipleChoiseTaskRepository = { TestableRepositories.testable(with: database).multipleChoiceTaskRepository }()

    func testUpdateFlashAnswer() {
        failableTest {

            let user = try User.create(on: app)

            let subtopic = try Subtopic.create(on: app)

            _ = try FlashCardTask.create(subtopic: subtopic, on: app)
            _ = try FlashCardTask.create(subtopic: subtopic, on: app)
            _ = try FlashCardTask.create(subtopic: subtopic, on: app)
            _ = try FlashCardTask.create(subtopic: subtopic, on: app)

            let session = try PracticeSession.create(in: [subtopic.id], for: user, on: database)

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

        let user = try User.create(on: app)
        let unverifiedUser = try User.create(isAdmin: false, isEmailVerified: false, on: app)

        let subtopic = try Subtopic.create(on: app)

        _ = try FlashCardTask.create(subtopic: subtopic, on: app)
        _ = try FlashCardTask.create(subtopic: subtopic, on: app)
        _ = try FlashCardTask.create(subtopic: subtopic, on: app)
        _ = try FlashCardTask.create(subtopic: subtopic, on: app)

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

        let user = try User.create(on: app)

        let subtopic = try Subtopic.create(on: app)

        _ = try FlashCardTask.create(subtopic: subtopic, on: app)
        _ = try FlashCardTask.create(subtopic: subtopic, on: app)
        _ = try FlashCardTask.create(subtopic: subtopic, on: app)
        _ = try FlashCardTask.create(subtopic: subtopic, on: app)

        let session = try PracticeSession.create(in: [subtopic.id], for: user, on: database)

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

        let user = try User.create(on: app)

        let subtopic = try Subtopic.create(on: app)

        _ = try MultipleChoiceTask.create(subtopic: subtopic, on: app)
        _ = try MultipleChoiceTask.create(subtopic: subtopic, on: app)
        _ = try MultipleChoiceTask.create(subtopic: subtopic, on: app)
        _ = try MultipleChoiceTask.create(subtopic: subtopic, on: app)

        let session = try PracticeSession.create(in: [subtopic.id], for: user, on: database)

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
            let user = try User.create(on: app)

            let subtopic = try Subtopic.create(on: app)

            let taskOne = try MultipleChoiceTask.create(subtopic: subtopic, on: app)
            let taskTwo = try MultipleChoiceTask.create(subtopic: subtopic, on: app)

            let create = PracticeSession.Create.Data(
                numberOfTaskGoal: 2,
                subtopicsIDs: [subtopic.id],
                topicIDs: nil
            )

            let session = try practiceSessionRepository.create(from: create, by: user).wait()
            let representable = try session.representable(on: database).wait()

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
            XCTAssertEqual(try MultipleChoiseTaskAnswer.query(on: database).count().wait(), 1)
            XCTAssertEqual(try TaskSessionAnswer.query(on: database).count().wait(), 1)

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

            XCTAssertEqual(try MultipleChoiseTaskAnswer.query(on: database).count().wait(), 2)
            XCTAssertEqual(try TaskSessionAnswer.query(on: database).count().wait(), 2)
            XCTAssertNotNil(representable.endedAt)

        } catch {
            XCTFail(error.localizedDescription)
        }
    }

    func testPracticeSessionAssignmentWithTestTasks() throws {
        do {
            let user = try User.create(on: app)

            let subtopic = try Subtopic.create(on: app)

            _ = try MultipleChoiceTask.create(subtopic: subtopic, on: app)
            _ = try MultipleChoiceTask.create(subtopic: subtopic, on: app)
            let taskThree = try MultipleChoiceTask.create(subtopic: subtopic, on: app)
            let testTask = try TaskDatabaseModel.create(subtopic: subtopic, isTestable: true, on: app)

            _ = try multipleChoiceRepository.deleteModelWith(id: taskThree.id, by: user).wait()

            let create = PracticeSession.Create.Data(
                numberOfTaskGoal: 2,
                subtopicsIDs: [subtopic.id],
                topicIDs: nil
            )

            let session = try practiceSessionRepository.create(from: create, by: user).wait()
            let representable = try session.representable(on: database).wait()

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

        let user = try User.create(isAdmin: false, on: app)

        let subtopic = try Subtopic.create(on: app)

        _ = try MultipleChoiceTask.create(subtopic: subtopic, on: app)
        _ = try MultipleChoiceTask.create(subtopic: subtopic, on: app)

        let create = PracticeSession.Create.Data(
            numberOfTaskGoal: 2,
            subtopicsIDs: [subtopic.id],
            topicIDs: nil
        )

        XCTAssertThrowsError(
            try practiceSessionRepository
                .create(from: create, by: user).wait()
        )
        XCTAssertEqual(try PracticeSession.DatabaseModel.query(on: database).count().wait(), 0)
    }

    func testPracticeSessionAssignmentMultiple() throws {

        let user = try User.create(on: app)

        let subtopic = try Subtopic.create(on: app)

        let taskOne = try MultipleChoiceTask.create(subtopic: subtopic, on: app)
        let taskTwo = try MultipleChoiceTask.create(subtopic: subtopic, on: app)

        let create = PracticeSession.Create.Data(
            numberOfTaskGoal: 2,
            subtopicsIDs: [subtopic.id],
            topicIDs: nil
        )

        _ = try practiceSessionRepository.create(from: create, by: user).wait()
        let session = try practiceSessionRepository.create(from: create, by: user).wait()
        let representable = try session.representable(on: database).wait()

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

        let user = try User.create(on: app)

        let subtopic = try Subtopic.create(on: app)

        _ = try MultipleChoiceTask.create(subtopic: subtopic, on: app)
        _ = try MultipleChoiceTask.create(subtopic: subtopic, on: app)
        _ = try MultipleChoiceTask.create(on: app)

        let create = PracticeSession.Create.Data(
            numberOfTaskGoal: 2,
            subtopicsIDs: [subtopic.id],
            topicIDs: nil
        )

        let firstSession = try practiceSessionRepository.create(from: create, by: user).wait()
        let secondSession = try practiceSessionRepository.create(from: create, by: user).wait()

        let firstRepresentable = try firstSession.representable(on: database).wait()
        let secondRepresentable = try secondSession.representable(on: database).wait()

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

        let user = try User.create(on: app)

        let subtopic = try Subtopic.create(on: app)

        _ = try MultipleChoiceTask.create(subtopic: subtopic, on: app)
        _ = try MultipleChoiceTask.create(subtopic: subtopic, on: app)
        _ = try MultipleChoiceTask.create(on: app)
        let createdSesssion = try PracticeSession.create(in: [subtopic.id], for: user, on: database)

        let parameterSession = try PracticeSession.PracticeParameter.resolveWith(createdSesssion.requireID(), database: database).wait()

        XCTAssertEqual(createdSesssion.id, parameterSession.id)
        XCTAssertEqual(createdSesssion.createdAt, parameterSession.createdAt)
        XCTAssertEqual(createdSesssion.id, parameterSession.id)
    }

    func testExtendSession() {
        failableTest {

            let user = try User.create(on: app)

            let subtopic = try Subtopic.create(on: app)

            _ = try MultipleChoiceTask.create(subtopic: subtopic, on: app)
            _ = try MultipleChoiceTask.create(subtopic: subtopic, on: app)
            _ = try MultipleChoiceTask.create(on: app)
            let createdSesssion = try PracticeSession.create(in: [subtopic.id], for: user, numberOfTaskGoal: 10, on: database)

            let parameterSession = try PracticeSession.PracticeParameter.resolveWith(createdSesssion.requireID(), database: database).wait()

            XCTAssertEqual(parameterSession.numberOfTaskGoal, 10)
            try practiceSessionRepository.extend(session: parameterSession, for: user).wait()
            XCTAssertEqual(parameterSession.numberOfTaskGoal, 15)
        }
    }

    func choisesAt(index: Int, for session: PracticeSessionRepresentable) throws -> [MultipleChoiseTaskChoise] {
        try PracticeSession.Pivot.Task.query(on: database)
            .filter(\PracticeSession.Pivot.Task.$session.$id == session.requireID())
            .filter(\.$index == index)
            .join(MultipleChoiseTaskChoise.self, on: \MultipleChoiseTaskChoise.$task.$id == \PracticeSession.Pivot.Task.$task.$id)
            .all(MultipleChoiseTaskChoise.self)
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
