//
//  FlashCardTaskTests.swift
//  KognitaCoreTests
//
//  Created by Eskild Brobak on 28/08/2019.
//

import Vapor
import XCTest
import FluentPostgreSQL
@testable import KognitaCore

class FlashCardTaskTests: VaporTestCase {

    func testCreateAsAdmin() throws {
        let subtopic = try Subtopic.create(on: conn)
        let user = try User.create(on: conn)

        let taskData = try FlashCardTask.Create.Data(
            subtopicId: subtopic.requireID(),
            description: nil,
            question: "Test",
            solution: "Some solution",
            isTestable: false,
            examPaperSemester: nil,
            examPaperYear: nil
        )

        do {
            let flashCardTask = try FlashCardTask.DatabaseRepository
                .create(from: taskData, by: user, on: conn)
                .wait()

            let solution = try TaskSolution.DatabaseRepository
                .solutions(for: flashCardTask.requireID(), for: user, on: conn)
                .wait()

            XCTAssertNotNil(flashCardTask.createdAt)
            XCTAssertEqual(flashCardTask.subtopicID, subtopic.id)
            XCTAssertEqual(flashCardTask.question, taskData.question)
            XCTAssertEqual(solution.first?.solution, taskData.solution)
            XCTAssertEqual(solution.first?.approvedBy, user.username)
        } catch {
            XCTFail(error.localizedDescription)
        }
    }

    func testCreateAsStudent() throws {
        let subtopic = try Subtopic.create(on: conn)
        let user = try User.create(isAdmin: false, on: conn)

        let taskData = try FlashCardTask.Create.Data(
            subtopicId: subtopic.requireID(),
            description: nil,
            question: "Test",
            solution: "Some solution",
            isTestable: false,
            examPaperSemester: nil,
            examPaperYear: nil
        )

        do {
            let flashCardTask = try FlashCardTask.DatabaseRepository
                .create(from: taskData, by: user, on: conn)
                .wait()

            let solution = try TaskSolution.DatabaseRepository
                .solutions(for: flashCardTask.requireID(), for: user, on: conn)
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
            let creatorStudent = try User.create(isAdmin: false, on: conn)
            let otherStudent = try User.create(isAdmin: false, on: conn)

            let startingFlash = try FlashCardTask.create(creator: creatorStudent, on: conn)
            var startingTask = try startingFlash.task!.get(on: conn).wait()

            let content = FlashCardTask.Create.Data(
                subtopicId: startingTask.subtopicID,
                description: nil,
                question: "Some question 2",
                solution: "Some solution",
                isTestable: false,
                examPaperSemester: nil,
                examPaperYear: nil
            )

            let editedTask = try FlashCardTask.DatabaseRepository
                .update(model: startingFlash, to: content, by: creatorStudent, on: conn).wait()
            startingTask = try Task.query(on: conn, withSoftDeleted: true)
                .filter(\.id == startingTask.id)
                .first()
                .unwrap(or: Abort(.internalServerError))
                .wait() // refershing

            XCTAssertEqual(editedTask.question, content.question)
            XCTAssertEqual(editedTask.id, startingTask.editedTaskID)

            let editedFlash = try FlashCardTask.find(editedTask.requireID(), on: conn).unwrap(or: Errors.badTest).wait()

            throwsError(of: Abort.self) {
                _ = try FlashCardTask.DatabaseRepository
                    .update(model: editedFlash, to: content, by: otherStudent, on: conn).wait()
            }
        }
    }

    func testAnswerIsSavedOnSubmit() throws {

        let user = try User.create(on: conn)

        let subtopic = try Subtopic.create(on: conn)

        let firstTask = try FlashCardTask.create(subtopic: subtopic, on: conn)
        let secondTask = try FlashCardTask.create(subtopic: subtopic, on: conn)

        let create = try PracticeSession.Create.Data(
            numberOfTaskGoal: 2,
            subtopicsIDs: [
                subtopic.requireID()
            ],
            topicIDs: nil
        )

        do {
            let session = try PracticeSession.DatabaseRepository
                .create(from: create, by: user, on: conn).wait()
            let superSession = try TaskSession
                .find(session.requireID(), on: conn)
                .unwrap(or: Abort(.internalServerError))
                .wait()
            let sessionRepresentable = session.representable(with: superSession)

            let firstSubmit = FlashCardTask.Submit(
                timeUsed: 20,
                knowledge: 2,
                taskIndex: 1,
                answer: "First Answer"
            )
            _ = try PracticeSession.DatabaseRepository
                .submit(firstSubmit, in: sessionRepresentable, by: user, on: conn).wait()

            let secondSubmit = FlashCardTask.Submit(
                timeUsed: 20,
                knowledge: 2,
                taskIndex: 2,
                answer: "Second Answer"
            )

            _ = try PracticeSession.DatabaseRepository
                .submit(secondSubmit, in: sessionRepresentable, by: user, on: conn).wait()

            let answers = try FlashCardAnswer.query(on: conn)
                .all()
                .wait()
            let answerSet = Set(answers.map { $0.answer })
            let taskIDSet = Set(answers.map { $0.taskID })

            let sessionAnswers = try TaskSessionAnswer.query(on: conn).all().wait()

            XCTAssertEqual(answers.count, 2)
            XCTAssert(sessionAnswers.allSatisfy { $0.sessionID == session.id })
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
        ("testEditAsStudent", testEditAsStudent),
    ]
}
