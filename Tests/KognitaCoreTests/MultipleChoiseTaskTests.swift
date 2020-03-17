//
//  MultipleChoiseTaskTests.swift
//  AppTests
//
//  Created by Mats Mollestad on 10/11/2018.
//

import Vapor
import XCTest
import FluentPostgreSQL
@testable import KognitaCore


class MultipleChoiseTaskTests: VaporTestCase {
    
    func testCreateAsAdmin() throws {
        let subtopic = try Subtopic.create(on: conn)
        let user = try User.create(on: conn)

        let taskData = try MultipleChoiseTask.Create.Data(
            subtopicId: subtopic.requireID(),
            description: nil,
            question: "Some question",
            solution: "Some solution",
            isMultipleSelect: false,
            examPaperSemester: nil,
            examPaperYear: nil,
            isTestable: true,
            choises: [
                .init(choise: "not", isCorrect: false),
                .init(choise: "yes", isCorrect: true)
            ]
        )
        let multiple = try MultipleChoiseTask.DatabaseRepository
            .create(from: taskData, by: user, on: conn)
            .wait()

        let content = try multiple
            .content(on: conn)
            .wait()

        let solution = try TaskSolution.DatabaseRepository
            .solutions(for: multiple.requireID(), for: user, on: conn)
            .wait()

        XCTAssertNotNil(multiple.createdAt)
        XCTAssertEqual(multiple.isMultipleSelect, content.isMultipleSelect)
        XCTAssertEqual(content.task.subtopicID, subtopic.id)
        XCTAssertEqual(content.task.question, taskData.question)
        XCTAssertEqual(solution.first?.solution, taskData.solution)
        XCTAssertEqual(solution.first?.approvedBy, user.username)
        XCTAssertEqual(content.choises.count, taskData.choises.count)
    }

    func testCreateAsStudent() throws {
        let subtopic = try Subtopic.create(on: conn)
        let user = try User.create(isAdmin: false, on: conn)

        let taskData = try MultipleChoiseTask.Create.Data(
            subtopicId: subtopic.requireID(),
            description: nil,
            question: "Some question",
            solution: "Some solution",
            isMultipleSelect: false,
            examPaperSemester: nil,
            examPaperYear: nil,
            isTestable: true,
            choises: [
                .init(choise: "not", isCorrect: false),
                .init(choise: "yes", isCorrect: true)
            ]
        )
        let multiple = try MultipleChoiseTask.DatabaseRepository
            .create(from: taskData, by: user, on: conn)
            .wait()

        let content = try multiple
            .content(on: conn)
            .wait()

        let solution = try TaskSolution.DatabaseRepository
            .solutions(for: multiple.requireID(), for: user, on: conn)
            .wait()

        XCTAssertNotNil(multiple.createdAt)
        XCTAssertEqual(multiple.isMultipleSelect, content.isMultipleSelect)
        XCTAssertEqual(content.task.subtopicID, subtopic.id)
        XCTAssertEqual(content.task.question, taskData.question)
        XCTAssertEqual(solution.first?.solution, taskData.solution)
        XCTAssertNil(solution.first?.approvedBy)
        XCTAssertEqual(content.choises.count, taskData.choises.count)
    }

    func testEdit() throws {
        let startingMultiple = try MultipleChoiseTask.create(on: conn)
        var startingTask = try startingMultiple.task!.get(on: conn).wait()
        let user = try User.create(on: conn)

        let content = MultipleChoiseTask.Create.Data(
            subtopicId: startingTask.subtopicID,
            description: nil,
            question: "Some question",
            solution: "Some solution",
            isMultipleSelect: false,
            examPaperSemester: nil,
            examPaperYear: nil,
            isTestable: true,
            choises: [
                .init(choise: "not", isCorrect: false),
                .init(choise: "yes", isCorrect: true)
            ]
        )

        let editedMultiple = try MultipleChoiseTask.DatabaseRepository
            .update(model: startingMultiple, to: content, by: user, on: conn).wait()
        let editedTask = try editedMultiple.task!.get(on: conn).wait()
        startingTask = try Task.query(on: conn, withSoftDeleted: true)
            .filter(\.id == startingTask.id)
            .first()
            .unwrap(or: Abort(.internalServerError))
            .wait() // refershing

        XCTAssertEqual(editedMultiple.isMultipleSelect, content.isMultipleSelect)
        XCTAssertEqual(editedTask.id, startingTask.editedTaskID)
    }

    func testEditAsStudent() throws {
        let creatorStudent = try User.create(isAdmin: false, on: conn)
        let otherStudent = try User.create(isAdmin: false, on: conn)

        let startingMultiple = try MultipleChoiseTask.create(creator: creatorStudent, on: conn)
        var startingTask = try startingMultiple.task!.get(on: conn).wait()

        let content = MultipleChoiseTask.Create.Data(
            subtopicId: startingTask.subtopicID,
            description: nil,
            question: "Some question",
            solution: "Some solution",
            isMultipleSelect: false,
            examPaperSemester: nil,
            examPaperYear: nil,
            isTestable: true,
            choises: [
                .init(choise: "not", isCorrect: false),
                .init(choise: "yes", isCorrect: true)
            ]
        )

        let editedMultiple = try MultipleChoiseTask.DatabaseRepository
            .update(model: startingMultiple, to: content, by: creatorStudent, on: conn).wait()
        let editedTask = try editedMultiple.task!.get(on: conn).wait()
        startingTask = try Task.query(on: conn, withSoftDeleted: true)
            .filter(\.id == startingTask.id)
            .first()
            .unwrap(or: Abort(.internalServerError))
            .wait() // refershing

        XCTAssertEqual(editedMultiple.isMultipleSelect, content.isMultipleSelect)
        XCTAssertEqual(editedTask.id, startingTask.editedTaskID)

        throwsError(of: Abort.self) {
            _ = try MultipleChoiseTask.DatabaseRepository
                .update(model: editedMultiple, to: content, by: otherStudent, on: conn).wait()
        }
    }

    func testEditEqualChoisesError() throws {
        _ = try MultipleChoiseTask.create(on: conn)
        let startingMultiple = try MultipleChoiseTask.create(on: conn)
        var startingTask = try startingMultiple.task!.get(on: conn).wait()
        let startingChoises = try startingMultiple.choises.query(on: conn).all().wait()
        let user = try User.create(on: conn)

        let content = MultipleChoiseTask.Create.Data(
            subtopicId: startingTask.subtopicID,
            description: startingTask.description,
            question: startingTask.question,
            solution: "Something",
            isMultipleSelect: startingMultiple.isMultipleSelect,
            examPaperSemester: startingTask.examPaperSemester,
            examPaperYear: startingTask.examPaperYear,
            isTestable: startingTask.isTestable,
            choises: startingChoises.map { .init(choise: $0.choise, isCorrect: $0.isCorrect) }
        )

        let editedMultiple = try MultipleChoiseTask.DatabaseRepository
            .update(model: startingMultiple, to: content, by: user, on: conn)
            .wait()
        let editedTask = try editedMultiple.task!.get(on: conn).wait()
        startingTask = try Task.query(on: conn, withSoftDeleted: true)
            .filter(\.id == startingTask.id)
            .first()
            .unwrap(or: Abort(.internalServerError))
            .wait() // refershing

        XCTAssertEqual(editedMultiple.isMultipleSelect, content.isMultipleSelect)
        XCTAssertEqual(editedTask.id, startingTask.editedTaskID)
    }

    func testAnswerIsSavedOnSubmit() throws {

        let user = try User.create(on: conn)

        let subtopic = try Subtopic.create(on: conn)

        _ = try MultipleChoiseTask.create(subtopic: subtopic, on: conn)
        _ = try MultipleChoiseTask.create(subtopic: subtopic, on: conn)

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
        let firstChoises = try firstTask.multipleChoise!.choises.query(on: conn).filter(\.isCorrect == true).all().wait()

        let firstSubmit = MultipleChoiseTask.Submit(
            timeUsed: 20,
            choises: firstChoises.compactMap { $0.id },
            taskIndex: 1
        )
        _ = try PracticeSession.DatabaseRepository
            .submit(firstSubmit, in: representable, by: user, on: conn).wait()

        let secondTask = try session.currentTask(on: conn).wait()
        let secondChoises = try secondTask.multipleChoise!.choises.query(on: conn).filter(\.isCorrect == false).all().wait()

        let secondSubmit = MultipleChoiseTask.Submit(
            timeUsed: 20,
            choises: secondChoises.compactMap { $0.id },
            taskIndex: 2
        )

        _ = try PracticeSession.DatabaseRepository
            .submit(secondSubmit, in: representable, by: user, on: conn).wait()

        let sessionAnswers = try TaskSessionAnswer.query(on: conn).all().wait()

        let answers = try MultipleChoiseTaskAnswer.query(on: conn).all().wait()
        XCTAssertEqual(answers.count, secondChoises.count + firstChoises.count)
        XCTAssert(sessionAnswers.allSatisfy { $0.sessionID == session.id })
        XCTAssert(answers.contains { $0.choiseID == firstChoises.first?.id })
        XCTAssert(answers.contains { answer in secondChoises.contains { answer.choiseID == $0.id }})
    }

    static var allTests = [
        ("testCreateAsAdmin", testCreateAsAdmin),
        ("testCreateAsStudent", testCreateAsStudent),
        ("testEdit", testEdit),
        ("testEditAsStudent", testEditAsStudent),
        ("testEditEqualChoisesError", testEditEqualChoisesError),
        ("testAnswerIsSavedOnSubmit", testAnswerIsSavedOnSubmit)
    ]
}
