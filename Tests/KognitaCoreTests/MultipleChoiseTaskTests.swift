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
    
    func testCreate() throws {
        let subtopic = try Subtopic.create(on: conn)
        let user = try User.create(on: conn)

        let content = try MultipleChoiseTask.Create.Data(
            subtopicId: subtopic.requireID(),
            description: nil,
            question: "Some question",
            solution: "Some solution",
            isMultipleSelect: false,
            examPaperSemester: nil,
            examPaperYear: nil,
            isExaminable: true,
            choises: [
                .init(choise: "not", isCorrect: false),
                .init(choise: "yes", isCorrect: true)
            ]
        )
        let multiple = try MultipleChoiseTask.Repository.create(from: content, by: user, on: conn).wait()
        let task = try multiple.task?.get(on: conn).wait()
        let choises = try multiple.choises.query(on: conn).all().wait()

        XCTAssertNotNil(multiple.createdAt)
        XCTAssertEqual(multiple.isMultipleSelect, content.isMultipleSelect)
        XCTAssertEqual(task?.id, multiple.id)
        XCTAssertEqual(choises.count, content.choises.count)
    }

    func testCreateWithoutPrivilage() throws {
        let subtopic = try Subtopic.create(on: conn)
        let user = try User.create(role: .user, on: conn)

        let content = try MultipleChoiseTask.Create.Data(
            subtopicId: subtopic.requireID(),
            description: nil,
            question: "Some question",
            solution: "Some solution",
            isMultipleSelect: false,
            examPaperSemester: nil,
            examPaperYear: nil,
            isExaminable: true,
            choises: [
                .init(choise: "not", isCorrect: false),
                .init(choise: "yes", isCorrect: true)
            ]
        )
        XCTAssertThrowsError(try MultipleChoiseTask.Repository.create(from: content, by: user, on: conn).wait())
    }

    func testEdit() throws {
        let startingMultiple = try MultipleChoiseTask.create(on: conn)
        var startingTask = try startingMultiple.task!.get(on: conn).wait()
        let user = try User.create(on: conn)

        let content = MultipleChoiseTask.Create.Data(
            subtopicId: startingTask.subtopicId,
            description: nil,
            question: "Some question",
            solution: "Some solution",
            isMultipleSelect: false,
            examPaperSemester: nil,
            examPaperYear: nil,
            isExaminable: true,
            choises: [
                .init(choise: "not", isCorrect: false),
                .init(choise: "yes", isCorrect: true)
            ]
        )

        let editedMultiple = try MultipleChoiseTask.Repository.edit(startingMultiple, to: content, by: user, on: conn).wait()
        let editedTask = try editedMultiple.task!.get(on: conn).wait()
        startingTask = try Task.query(on: conn, withSoftDeleted: true)
            .filter(\.id == startingTask.id)
            .first()
            .unwrap(or: Abort(.internalServerError))
            .wait() // refershing

        XCTAssertEqual(editedMultiple.isMultipleSelect, content.isMultipleSelect)
        XCTAssertEqual(editedTask.id, startingTask.editedTaskID)
    }

    func testEditEqualChoisesError() throws {
        _ = try MultipleChoiseTask.create(on: conn)
        let startingMultiple = try MultipleChoiseTask.create(on: conn)
        var startingTask = try startingMultiple.task!.get(on: conn).wait()
        let startingChoises = try startingMultiple.choises.query(on: conn).all().wait()
        let user = try User.create(on: conn)

        let content = MultipleChoiseTask.Create.Data(
            subtopicId: startingTask.subtopicId,
            description: startingTask.description,
            question: startingTask.question,
            solution: startingTask.solution,
            isMultipleSelect: startingMultiple.isMultipleSelect,
            examPaperSemester: startingTask.examPaperSemester,
            examPaperYear: startingTask.examPaperYear,
            isExaminable: startingTask.isExaminable,
            choises: startingChoises.map { .init(choise: $0.choise, isCorrect: $0.isCorrect) }
        )

        let editedMultiple = try MultipleChoiseTask.Repository.edit(startingMultiple, to: content, by: user, on: conn).wait()
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

        let session = try PracticeSession.Repository
            .create(from: create, by: user, on: conn).wait()

        let firstTask = try session.currentTask(on: conn).wait()
        let firstChoises = try firstTask.multipleChoise!.choises.query(on: conn).filter(\.isCorrect == true).all().wait()

        let firstSubmit = MultipleChoiseTask.Submit(
            timeUsed: 20,
            choises: firstChoises.compactMap { $0.id },
            taskIndex: 1
        )
        _ = try PracticeSession.Repository
            .submitMultipleChoise(firstSubmit, in: session, by: user, on: conn).wait()

        let secondTask = try session.currentTask(on: conn).wait()
        let secondChoises = try secondTask.multipleChoise!.choises.query(on: conn).filter(\.isCorrect == false).all().wait()

        let secondSubmit = MultipleChoiseTask.Submit(
            timeUsed: 20,
            choises: secondChoises.compactMap { $0.id },
            taskIndex: 2
        )

        _ = try PracticeSession.Repository
            .submitMultipleChoise(secondSubmit, in: session, by: user, on: conn).wait()

        let answers = try MultipleChoiseTaskAnswer.query(on: conn).all().wait()
        XCTAssertEqual(answers.count, secondChoises.count + firstChoises.count)
        XCTAssert(answers.allSatisfy { $0.sessionID == session.id })
        XCTAssert(answers.contains { $0.choiseID == firstChoises.first?.id })
        XCTAssert(answers.contains { answer in secondChoises.contains { answer.choiseID == $0.id }})
    }

    static var allTests = [
        ("testCreate", testCreate),
        ("testCreateWithoutPrivilage", testCreateWithoutPrivilage),
        ("testEdit", testEdit),
        ("testEditEqualChoisesError", testEditEqualChoisesError),
        ("testAnswerIsSavedOnSubmit", testAnswerIsSavedOnSubmit)
    ]
}
