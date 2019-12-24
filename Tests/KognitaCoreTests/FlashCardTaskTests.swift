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

    func testCreate() throws {
        let subtopic = try Subtopic.create(on: conn)
        let user = try User.create(on: conn)

        let taskData = try FlashCardTask.Create.Data(
            subtopicId: subtopic.requireID(),
            description: nil,
            question: "Test",
            solution: "Some solution",
            isExaminable: false,
            examPaperSemester: nil,
            examPaperYear: nil
        )

        do {
            let flashCardTask = try FlashCardTask.DatabaseRepository
                .create(from: taskData, by: user, on: conn)
                .wait()

            let solution = try TaskSolution.Repository
                .solutions(for: flashCardTask.requireID(), on: conn)
                .wait()

            XCTAssertNotNil(flashCardTask.createdAt)
            XCTAssertEqual(flashCardTask.subtopicID, subtopic.id)
            XCTAssertEqual(flashCardTask.question, taskData.question)
            XCTAssertEqual(solution.first?.solution, taskData.solution)
        } catch {
            XCTFail(error.localizedDescription)
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

            let firstSubmit = FlashCardTask.Submit(
                timeUsed: 20,
                knowledge: 2,
                taskIndex: 1,
                answer: "First Answer"
            )
            _ = try PracticeSession.DatabaseRepository
                .submitFlashCard(firstSubmit, in: session, by: user, on: conn).wait()

            let secondSubmit = FlashCardTask.Submit(
                timeUsed: 20,
                knowledge: 2,
                taskIndex: 2,
                answer: "Second Answer"
            )

            _ = try PracticeSession.DatabaseRepository
                .submitFlashCard(secondSubmit, in: session, by: user, on: conn).wait()

            let answers = try FlashCardAnswer.query(on: conn)
                .all()
                .wait()
            let answerSet = Set(answers.map { $0.answer })
            let taskIDSet = Set(answers.map { $0.taskID })

            XCTAssertEqual(answers.count, 2)
            XCTAssert(answers.allSatisfy { $0.sessionID == session.id })
            XCTAssertTrue(answerSet.contains(firstSubmit.answer), "First submitted answer not found in \(answerSet)")
            XCTAssertTrue(answerSet.contains(secondSubmit.answer), "Second submitted answer not found in \(answerSet)")
            XCTAssertTrue(try taskIDSet.contains(firstTask.requireID()), "First submitted task id not found in \(taskIDSet)")
            XCTAssertTrue(try taskIDSet.contains(secondTask.requireID()), "Second submitted task id not found in \(taskIDSet)")
        } catch {
            XCTFail(error.localizedDescription)
        }
    }

    static var allTests = [
        ("testCreate", testCreate),
        ("testAnswerIsSavedOnSubmit", testAnswerIsSavedOnSubmit),
    ]
}
