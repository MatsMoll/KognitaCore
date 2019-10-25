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

        let session = try PracticeSession.Repository
            .create(from: create, by: user, on: conn).wait()

        let firstSubmit = FlashCardTask.Submit(
            timeUsed: 20,
            knowledge: 2,
            taskIndex: 1,
            answer: "First Answer"
        )
        _ = try PracticeSession.Repository
            .submitFlashCard(firstSubmit, in: session, by: user, on: conn).wait()

        let secondSubmit = FlashCardTask.Submit(
            timeUsed: 20,
            knowledge: 2,
            taskIndex: 2,
            answer: "Second Answer"
        )

        _ = try PracticeSession.Repository
            .submitFlashCard(secondSubmit, in: session, by: user, on: conn).wait()

        let answers = try FlashCardAnswer.query(on: conn).all().wait()
        XCTAssertEqual(answers.count, 2)
        XCTAssert(answers.allSatisfy { $0.sessionID == session.id })
        XCTAssert(answers.contains { $0.taskID == firstTask.id && $0.answer == firstSubmit.answer })
        XCTAssert(answers.contains { $0.taskID == secondTask.id && $0.answer == secondSubmit.answer })
    }

    static var allTests = [
        ("testAnswerIsSavedOnSubmit", testAnswerIsSavedOnSubmit),
    ]
}
