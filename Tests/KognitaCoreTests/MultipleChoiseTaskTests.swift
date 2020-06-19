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
import KognitaCoreTestable

class MultipleChoiseTaskTests: VaporTestCase {

    lazy var multipleChoiceRepository: MultipleChoiseTaskRepository = { TestableRepositories.testable(with: conn).multipleChoiceTaskRepository }()
    lazy var taskSolutionRepository: TaskSolutionRepositoring = { TestableRepositories.testable(with: conn).taskSolutionRepository }()
    lazy var practiceSessionRepository: PracticeSessionRepository = { TestableRepositories.testable(with: conn).practiceSessionRepository }()

    func testCreateAsAdmin() throws {
        let subtopic = try Subtopic.create(on: conn)
        let user = try User.create(on: conn)

        let taskData = MultipleChoiceTask.Create.Data(
            subtopicId: subtopic.id,
            description: "",
            question: "Some question",
            solution: "Some solution",
            isMultipleSelect: false,
            examPaperSemester: nil,
            examPaperYear: nil,
            isTestable: true,
            choises: [
                .init(choice: "not", isCorrect: false),
                .init(choice: "yes", isCorrect: true)
            ]
        )
        let multiple = try multipleChoiceRepository
            .create(from: taskData, by: user)
            .wait()

        let solution = try taskSolutionRepository
            .solutions(for: multiple.id, for: user)
            .wait()

        XCTAssertNotNil(multiple.createdAt)
        XCTAssertEqual(multiple.isMultipleSelect, taskData.isMultipleSelect)
        XCTAssertEqual(multiple.subtopicID, taskData.subtopicId)
        XCTAssertEqual(multiple.description, nil)
        XCTAssertEqual(multiple.question, taskData.question)
        XCTAssertEqual(solution.first?.solution, taskData.solution)
        XCTAssertEqual(solution.first?.approvedBy, user.username)
        XCTAssertEqual(multiple.choises.count, taskData.choises.count)
    }

    func testCreateAsStudent() throws {
        let subtopic = try Subtopic.create(on: conn)
        let user = try User.create(isAdmin: false, on: conn)

        let taskData = MultipleChoiceTask.Create.Data(
            subtopicId: subtopic.id,
            description: nil,
            question: "Some question",
            solution: "Some solution",
            isMultipleSelect: false,
            examPaperSemester: nil,
            examPaperYear: nil,
            isTestable: true,
            choises: [
                .init(choice: "not", isCorrect: false),
                .init(choice: "yes", isCorrect: true)
            ]
        )
        let multiple = try multipleChoiceRepository
            .create(from: taskData, by: user)
            .wait()

        let solution = try taskSolutionRepository
            .solutions(for: multiple.id, for: user)
            .wait()

        XCTAssertNotNil(multiple.createdAt)
        XCTAssertEqual(multiple.isMultipleSelect, taskData.isMultipleSelect)
        XCTAssertEqual(multiple.subtopicID, subtopic.id)
        XCTAssertEqual(multiple.question, taskData.question)
        XCTAssertEqual(solution.first?.solution, taskData.solution)
        XCTAssertNil(solution.first?.approvedBy)
        XCTAssertEqual(multiple.choises.count, taskData.choises.count)
    }

    func testEdit() throws {
        let startingMultiple = try MultipleChoiceTask.create(on: conn)
        let user = try User.create(on: conn)

        let content = MultipleChoiceTask.Create.Data(
            subtopicId: startingMultiple.subtopicID,
            description: nil,
            question: "Some question",
            solution: "Some solution",
            isMultipleSelect: false,
            examPaperSemester: nil,
            examPaperYear: nil,
            isTestable: true,
            choises: [
                .init(choice: "not", isCorrect: false),
                .init(choice: "yes", isCorrect: true)
            ]
        )

        let editedMultiple = try multipleChoiceRepository
            .updateModelWith(id: startingMultiple.id, to: content, by: user).wait()

        let startingTask = try Task.query(on: conn, withSoftDeleted: true)
            .filter(\.id == startingMultiple.id)
            .first()
            .unwrap(or: Abort(.internalServerError))
            .wait() // refershing

        XCTAssertEqual(editedMultiple.isMultipleSelect, content.isMultipleSelect)
        XCTAssertEqual(editedMultiple.id, startingTask.editedTaskID)
    }

    func testEditAsStudent() throws {
        let creatorStudent = try User.create(isAdmin: false, on: conn)
        let otherStudent = try User.create(isAdmin: false, on: conn)

        let startingMultiple = try MultipleChoiceTask.create(creator: creatorStudent, on: conn)

        let content = MultipleChoiceTask.Create.Data(
            subtopicId: startingMultiple.subtopicID,
            description: nil,
            question: "Some question",
            solution: "Some solution",
            isMultipleSelect: false,
            examPaperSemester: nil,
            examPaperYear: nil,
            isTestable: true,
            choises: [
                .init(choice: "not", isCorrect: false),
                .init(choice: "yes", isCorrect: true)
            ]
        )

        let editedMultiple = try multipleChoiceRepository
            .updateModelWith(id: startingMultiple.id, to: content, by: creatorStudent).wait()

        let startingTask = try Task.query(on: conn, withSoftDeleted: true)
            .filter(\.id == startingMultiple.id)
            .first()
            .unwrap(or: Abort(.internalServerError))
            .wait() // refershing

        XCTAssertEqual(editedMultiple.isMultipleSelect, content.isMultipleSelect)
        XCTAssertEqual(editedMultiple.id, startingTask.editedTaskID)

        throwsError(of: Abort.self) {
            _ = try multipleChoiceRepository
                .updateModelWith(id: editedMultiple.id, to: content, by: otherStudent).wait()
        }
    }

    func testEditEqualChoisesError() throws {
        _ = try MultipleChoiceTask.create(on: conn)
        let startingMultiple = try MultipleChoiceTask.create(on: conn)

        let user = try User.create(on: conn)

        let content = MultipleChoiceTask.Create.Data(
            subtopicId: startingMultiple.subtopicID,
            description: startingMultiple.description,
            question: startingMultiple.question,
            solution: "Something",
            isMultipleSelect: startingMultiple.isMultipleSelect,
            examPaperSemester: nil,
            examPaperYear: startingMultiple.examYear,
            isTestable: startingMultiple.isTestable,
            choises: startingMultiple.choises.map { MultipleChoiceTaskChoice.Create.Data(choice: $0.choise, isCorrect: $0.isCorrect) }
        )

        let editedMultiple = try multipleChoiceRepository
            .updateModelWith(id: startingMultiple.id, to: content, by: user)
            .wait()

        let startingTask = try Task.query(on: conn, withSoftDeleted: true)
            .filter(\.id == startingMultiple.id)
            .first()
            .unwrap(or: Abort(.internalServerError))
            .wait() // refershing

        XCTAssertEqual(editedMultiple.isMultipleSelect, content.isMultipleSelect)
        XCTAssertEqual(editedMultiple.id, startingTask.editedTaskID)
    }

    func testNonCorrectAnswers() {
        failableTest {
            _ = try MultipleChoiceTask.create(on: conn)
            let startingMultiple = try MultipleChoiceTask.create(on: conn)

            let user = try User.create(on: conn)

            let content = MultipleChoiceTask.Create.Data(
                subtopicId: startingMultiple.subtopicID,
                description: startingMultiple.description,
                question: startingMultiple.question,
                solution: "Something",
                isMultipleSelect: startingMultiple.isMultipleSelect,
                examPaperSemester: nil,
                examPaperYear: startingMultiple.examYear,
                isTestable: startingMultiple.isTestable,
                choises: (0...3).map { _ in MultipleChoiceTaskChoice.Create.Data(choice: "Test", isCorrect: false) }
            )

            XCTAssertThrowsError(
                try multipleChoiceRepository
                    .updateModelWith(id: startingMultiple.id, to: content, by: user)
                    .wait()
            )
        }
    }

    func testAnswerIsSavedOnSubmit() throws {

        let user = try User.create(on: conn)

        let subtopic = try Subtopic.create(on: conn)

        _ = try MultipleChoiceTask.create(subtopic: subtopic, on: conn)
        _ = try MultipleChoiceTask.create(subtopic: subtopic, on: conn)

        let create = PracticeSession.Create.Data(
            numberOfTaskGoal: 2,
            subtopicsIDs: [subtopic.id],
            topicIDs: nil
        )

        let session = try practiceSessionRepository
            .create(from: create, by: user).wait()
        let representable = try session.representable(on: conn).wait()

        let firstTask = try practiceSessionRepository.currentActiveTask(in: session).wait()
        let firstChoises = try firstTask.multipleChoise!.choises.query(on: conn).filter(\.isCorrect == true).all().wait()

        let firstSubmit = MultipleChoiceTask.Submit(
            timeUsed: 20,
            choises: firstChoises.compactMap { $0.id },
            taskIndex: 1
        )
        _ = try practiceSessionRepository
            .submit(firstSubmit, in: representable, by: user).wait()

        let secondTask = try practiceSessionRepository.currentActiveTask(in: session).wait()
        let secondChoises = try secondTask.multipleChoise!.choises.query(on: conn).filter(\.isCorrect == false).all().wait()

        let secondSubmit = MultipleChoiceTask.Submit(
            timeUsed: 20,
            choises: secondChoises.compactMap { $0.id },
            taskIndex: 2
        )

        _ = try practiceSessionRepository
            .submit(secondSubmit, in: representable, by: user).wait()

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
