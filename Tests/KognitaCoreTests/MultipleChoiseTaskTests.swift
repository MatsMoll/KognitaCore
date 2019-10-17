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

    static var allTests = [
        ("testCreate", testCreate),
        ("testCreateWithoutPrivilage", testCreateWithoutPrivilage),
        ("testEdit", testEdit),
        ("testEditEqualChoisesError", testEditEqualChoisesError),
    ]
}
