//
//  FlashCardTaskTests.swift
//  KognitaCoreTests
//
//  Created by Eskild Brobak on 28/08/2019.
//

import Vapor
import XCTest
import FluentKit
@testable import KognitaCore
import KognitaCoreTestable

class FlashCardTaskTests: VaporTestCase {

    lazy var typingTaskRepository: TypingTaskRepository = { TestableRepositories.testable(with: app).typingTaskRepository }()
    lazy var practiceSessionRepository: PracticeSessionRepository = { TestableRepositories.testable(with: app).practiceSessionRepository }()
    lazy var taskSolutionRepository: TaskSolutionRepositoring = { TestableRepositories.testable(with: app).taskSolutionRepository }()

    func testCreateAsAdmin() throws {

        let subtopic = try Subtopic.create(on: app)
        let user = try User.create(on: app)

        let taskData = TypingTask.Create.Data(
            subtopicId: subtopic.id,
            description: nil,
            question: "Test",
            solution: "Some solution",
            isTestable: false,
            examID: nil
        )

        let flashCardTask = try typingTaskRepository
            .create(from: taskData, by: user)
            .wait()

        let solution = try taskSolutionRepository
            .solutions(for: flashCardTask.id, for: user)
            .wait()

        XCTAssertNotNil(flashCardTask.createdAt)
        XCTAssertEqual(flashCardTask.subtopicID, subtopic.id)
        XCTAssertEqual(flashCardTask.question, taskData.question)
        XCTAssertEqual(solution.first?.solution, taskData.solution)
        XCTAssertEqual(solution.first?.approvedBy, user.username)
    }

    func testCreateAsStudent() throws {
        let subtopic = try Subtopic.create(on: app)
        let user = try User.create(isAdmin: false, on: app)

        let taskData = TypingTask.Create.Data(
            subtopicId: subtopic.id,
            description: nil,
            question: "Test",
            solution: "Some solution",
            isTestable: false,
            examID: nil
        )

        do {
            let flashCardTask = try typingTaskRepository
                .create(from: taskData, by: user)
                .wait()

            let solution = try taskSolutionRepository
                .solutions(for: flashCardTask.id, for: user)
                .wait()

            XCTAssertNotNil(flashCardTask.createdAt)
            XCTAssertEqual(flashCardTask.subtopicID, subtopic.id)
            XCTAssertEqual(flashCardTask.question, taskData.question)
            XCTAssertEqual(solution.first?.solution, taskData.solution)
            XCTAssertNil(solution.first?.approvedBy)
        } catch {
            XCTFail(error.localizedDescription)
        }
    }

    func testEditAsStudent() {
        failableTest {
            let creatorStudent = try User.create(isAdmin: false, on: app)
            let otherStudent = try User.create(isAdmin: false, on: app)

            let startingFlash = try FlashCardTask.create(creator: creatorStudent, on: app)
            var startingTask = try TaskDatabaseModel.find(startingFlash.id!, on: database).unwrap(or: Errors.badTest).wait()

            let content = TypingTask.Create.Data(
                subtopicId: startingTask.$subtopic.id,
                description: nil,
                question: "Some question 2",
                solution: "Some solution",
                isTestable: false,
                examID: nil
            )

            let editedTask = try typingTaskRepository
                .updateModelWith(id: startingFlash.id!, to: content, by: creatorStudent).wait()
            startingTask = try TaskDatabaseModel.query(on: database)
                .withDeleted()
                .filter(\.$id == startingTask.id!)
                .first()
                .unwrap(or: Abort(.internalServerError))
                .wait() // refershing

            XCTAssertEqual(editedTask.question, content.question)

            let editedFlash = try FlashCardTask.find(editedTask.id, on: database).unwrap(or: Errors.badTest).wait()

            throwsError(of: Abort.self) {
                _ = try typingTaskRepository
                    .updateModelWith(id: editedFlash.id!, to: content, by: otherStudent)
                    .wait()
            }
        }
    }

    func testAnswerIsSavedOnSubmit() throws {

        let user = try User.create(on: app)

        let subtopic = try Subtopic.create(on: app)

        let firstTask = try FlashCardTask.create(subtopic: subtopic, on: app)
        let secondTask = try FlashCardTask.create(subtopic: subtopic, on: app)

        let create = PracticeSession.Create.Data(
            numberOfTaskGoal: 2,
            subtopicsIDs: [subtopic.id],
            topicIDs: nil
        )

        do {
            let session = try practiceSessionRepository
                .create(from: create, by: user).wait()
            let sessionRepresentable = try session.representable(on: database).wait()

            let firstSubmit = TypingTask.Submit(
                timeUsed: 20,
                knowledge: 2,
                taskIndex: 1,
                answer: "First Answer"
            )
            _ = try practiceSessionRepository
                .submit(firstSubmit, in: sessionRepresentable, by: user).wait()

            let secondSubmit = TypingTask.Submit(
                timeUsed: 20,
                knowledge: 2,
                taskIndex: 2,
                answer: "Second Answer"
            )

            _ = try practiceSessionRepository
                .submit(secondSubmit, in: sessionRepresentable, by: user).wait()

            let answers = try FlashCardAnswer.query(on: database)
                .all()
                .wait()
            let answerSet = Set(answers.map { $0.answer })
            let taskIDSet = Set(answers.map { $0.$task.id })

            let sessionAnswers = try TaskSessionAnswer.query(on: database).all().wait()

            XCTAssertEqual(answers.count, 2)
            XCTAssert(sessionAnswers.allSatisfy { $0.$session.id == session.id })
            XCTAssertTrue(answerSet.contains(firstSubmit.answer), "First submitted answer not found in \(answerSet)")
            XCTAssertTrue(answerSet.contains(secondSubmit.answer), "Second submitted answer not found in \(answerSet)")
            XCTAssertTrue(try taskIDSet.contains(firstTask.requireID()), "First submitted task id not found in \(taskIDSet)")
            XCTAssertTrue(try taskIDSet.contains(secondTask.requireID()), "Second submitted task id not found in \(taskIDSet)")
        } catch {
            XCTFail(error.localizedDescription)
        }
    }

    static var allTests = [
        ("testCreateAsAdmin", testCreateAsAdmin),
        ("testCreateAsStudent", testCreateAsStudent),
        ("testAnswerIsSavedOnSubmit", testAnswerIsSavedOnSubmit),
        ("testEditAsStudent", testEditAsStudent)
    ]
}
