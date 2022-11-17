//
//  MultipleChoiseTaskTests.swift
//  AppTests
//
//  Created by Mats Mollestad on 10/11/2018.
//

import Vapor
import XCTest
import FluentKit
@testable import KognitaCore
import KognitaCoreTestable

class MultipleChoiseTaskTests: VaporTestCase {

    lazy var multipleChoiceRepository: MultipleChoiseTaskRepository = { TestableRepositories.testable(with: app).multipleChoiceTaskRepository }()
    lazy var taskSolutionRepository: TaskSolutionRepositoring = { TestableRepositories.testable(with: app).taskSolutionRepository }()
    lazy var practiceSessionRepository: PracticeSessionRepository = { TestableRepositories.testable(with: app).practiceSessionRepository }()

    func testCreateAsAdmin() throws {
        let subtopic = try Subtopic.create(on: app)
        let user = try User.create(on: app)

        let taskData = MultipleChoiceTask.Create.Data(
            subtopicId: subtopic.id,
            description: nil,
            question: "Some question",
            solution: "Some solution",
            isMultipleSelect: false,
            examID: nil,
            isTestable: true,
            choises: [
                .init(choice: "not", isCorrect: false),
                .init(choice: "yes", isCorrect: true)
            ],
            resources: []
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
        let subtopic = try Subtopic.create(on: app)
        let user = try User.create(isAdmin: false, on: app)

        let taskData = MultipleChoiceTask.Create.Data(
            subtopicId: subtopic.id,
            description: nil,
            question: "Some question",
            solution: "Some solution",
            isMultipleSelect: false,
            examID: nil,
            isTestable: true,
            choises: [
                .init(choice: "not", isCorrect: false),
                .init(choice: "yes", isCorrect: true)
            ],
            resources: []
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
        let startingMultiple = try MultipleChoiceTask.create(on: app)
        let user = try User.create(on: app)

        let content = MultipleChoiceTask.Create.Data(
            subtopicId: startingMultiple.subtopicID,
            description: nil,
            question: "Some question",
            solution: "Some solution",
            isMultipleSelect: false,
            examID: nil,
            isTestable: true,
            choises: [
                .init(choice: "not", isCorrect: false),
                .init(choice: "yes", isCorrect: true)
            ],
            resources: []
        )

        let editedMultiple = try multipleChoiceRepository
            .updateModelWith(id: startingMultiple.id, to: content, by: user).wait()

        let startingTask = try TaskDatabaseModel.query(on: database)
            .withDeleted()
            .filter(\.$id == startingMultiple.id)
            .first()
            .unwrap(or: Abort(.internalServerError))
            .wait() // refershing

        XCTAssertEqual(editedMultiple.isMultipleSelect, content.isMultipleSelect)
    }

    func testEditAsStudent() throws {
        let creatorStudent = try User.create(isAdmin: false, on: app)
        let otherStudent = try User.create(isAdmin: false, on: app)

        let startingMultiple = try MultipleChoiceTask.create(creator: creatorStudent, on: app)

        let content = MultipleChoiceTask.Create.Data(
            subtopicId: startingMultiple.subtopicID,
            description: nil,
            question: "Some question",
            solution: "Some solution",
            isMultipleSelect: false,
            examID: nil,
            isTestable: true,
            choises: [
                .init(choice: "not", isCorrect: false),
                .init(choice: "yes", isCorrect: true)
            ],
            resources: []
        )

        let editedMultiple = try multipleChoiceRepository
            .updateModelWith(id: startingMultiple.id, to: content, by: creatorStudent).wait()

        let startingTask = try TaskDatabaseModel.query(on: database)
            .withDeleted()
            .filter(\.$id == startingMultiple.id)
            .first()
            .unwrap(or: Abort(.internalServerError))
            .wait() // refershing

        XCTAssertEqual(editedMultiple.isMultipleSelect, content.isMultipleSelect)

        throwsError(of: Abort.self) {
            _ = try multipleChoiceRepository
                .updateModelWith(id: editedMultiple.id, to: content, by: otherStudent).wait()
        }
    }

    func testEditEqualChoisesError() throws {
        _ = try MultipleChoiceTask.create(on: app)
        let startingMultiple = try MultipleChoiceTask.create(on: app)

        let user = try User.create(on: app)

        let content = MultipleChoiceTask.Create.Data(
            subtopicId: startingMultiple.subtopicID,
            description: startingMultiple.description,
            question: startingMultiple.question,
            solution: "Something",
            isMultipleSelect: startingMultiple.isMultipleSelect,
            examID: nil,
            isTestable: startingMultiple.isTestable,
            choises: startingMultiple.choises.map { MultipleChoiceTaskChoice.Create.Data(choice: $0.choice, isCorrect: $0.isCorrect) },
            resources: []
        )

        let editedMultiple = try multipleChoiceRepository
            .updateModelWith(id: startingMultiple.id, to: content, by: user)
            .wait()

        let startingTask = try TaskDatabaseModel.query(on: database)
            .withDeleted()
            .filter(\.$id == startingMultiple.id)
            .first()
            .unwrap(or: Abort(.internalServerError))
            .wait() // refershing

        XCTAssertEqual(editedMultiple.isMultipleSelect, content.isMultipleSelect)
    }

    func testNonCorrectAnswers() throws {
        _ = try MultipleChoiceTask.create(on: app)
        let startingMultiple = try MultipleChoiceTask.create(on: app)

        let user = try User.create(on: app)

        let content = MultipleChoiceTask.Create.Data(
            subtopicId: startingMultiple.subtopicID,
            description: startingMultiple.description,
            question: startingMultiple.question,
            solution: "Something",
            isMultipleSelect: startingMultiple.isMultipleSelect,
            examID: nil,
            isTestable: startingMultiple.isTestable,
            choises: (0...3).map { _ in MultipleChoiceTaskChoice.Create.Data(choice: "Test", isCorrect: false) },
            resources: []
        )

        XCTAssertThrowsError(
            try multipleChoiceRepository
                .updateModelWith(id: startingMultiple.id, to: content, by: user)
                .wait()
        )
    }

    func testAnswerIsSavedOnSubmit() throws {

        let user = try User.create(on: app)

        let subtopic = try Subtopic.create(on: app)

        _ = try MultipleChoiceTask.create(subtopic: subtopic, on: app)
        _ = try MultipleChoiceTask.create(subtopic: subtopic, on: app)

        let create = PracticeSession.Create.Data(
            numberOfTaskGoal: 2,
            subtopicsIDs: [subtopic.id],
            topicIDs: nil
        )

        let session = try practiceSessionRepository
            .create(from: create, by: user).wait()
        let representable = try session.representable(on: database).wait()

        let firstTask = try practiceSessionRepository.currentActiveTask(in: session).wait()
        let firstChoises = try multipleChoiceRepository.choisesFor(taskID: firstTask.taskID).wait()

        let firstSubmit = MultipleChoiceTask.Submit(
            timeUsed: 20,
            choises: firstChoises.compactMap { $0.id },
            taskIndex: 1
        )
        _ = try practiceSessionRepository
            .submit(firstSubmit, in: representable, by: user).wait()

        let secondTask = try practiceSessionRepository.currentActiveTask(in: session).wait()
        let secondChoises = try multipleChoiceRepository.choisesFor(taskID: firstTask.taskID).wait()

        let secondSubmit = MultipleChoiceTask.Submit(
            timeUsed: 20,
            choises: secondChoises.compactMap { $0.id },
            taskIndex: 2
        )

        _ = try practiceSessionRepository
            .submit(secondSubmit, in: representable, by: user).wait()

        let sessionAnswers = try TaskSessionAnswer.query(on: database).all().wait()

        let answers = try MultipleChoiseTaskAnswer.query(on: database).all().wait()
        XCTAssertEqual(answers.count, secondChoises.count + firstChoises.count)
        XCTAssert(sessionAnswers.allSatisfy { $0.$session.id == session.id })
        XCTAssert(answers.contains { $0.$choice.id == firstChoises.first?.id })
        XCTAssert(answers.contains { answer in secondChoises.contains { answer.$choice.id == $0.id }})
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
