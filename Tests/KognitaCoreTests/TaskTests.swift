//
//  TaskTests.swift
//  App
//
//  Created by Mats Mollestad on 09/11/2018.
//

import Vapor
import XCTest
import FluentPostgreSQL
@testable import KognitaCore
import KognitaCoreTestable

class TaskTests: VaporTestCase {

    func testTasksInSubject() throws {

        let subject = try Subject.create(name: "test", on: conn)
        let topic = try Topic.create(subject: subject, on: conn)
        let subtopic = try Subtopic.create(topic: topic, on: conn)
        _ = try Task.create(subtopic: subtopic, on: conn)
        _ = try Task.create(subtopic: subtopic, on: conn)
        _ = try Task.create(subtopic: subtopic, on: conn)
        _ = try Task.create(subtopic: subtopic, on: conn)
        _ = try Task.create(on: conn)

        let tasks = try Task.Repository
            .getTasks(in: subject, with: conn)
            .wait()
        XCTAssertEqual(tasks.count, 4)
    }

    func testSolutions() throws {
        do {
            let task = try Task.create(createSolution: false, on: conn)
            let user = try User.create(on: conn)
            let secondUser = try User.create(isAdmin: false, on: conn)
            let firstSolution = try TaskSolution.create(task: task, presentUser: false, on: conn)
            let secondSolution = try TaskSolution.create(task: task, on: conn)
            _ = try TaskSolution.create(on: conn)

            secondSolution.isApproved = true
            secondSolution.approvedBy = try user.requireID()
            _ = try secondSolution.save(on: conn).wait()

            try TaskSolution.DatabaseRepository.upvote(for: firstSolution.requireID(), by: user, on: conn).wait()
            try TaskSolution.DatabaseRepository.upvote(for: firstSolution.requireID(), by: secondUser, on: conn).wait()

            let solutions = try TaskSolution.DatabaseRepository.solutions(for: task.requireID(), for: user, on: conn).wait()

            XCTAssertEqual(solutions.count, 2)

            let firstResponse = try XCTUnwrap(solutions.first(where: { $0.solution == firstSolution.solution }))
            XCTAssertEqual(firstResponse.creatorUsername, "Unknown")
            XCTAssertNil(firstResponse.approvedBy)
            XCTAssertEqual(firstResponse.numberOfVotes, 2)

            let secondResponse = try XCTUnwrap(solutions.first(where: { $0.solution == secondSolution.solution }))
            XCTAssertEqual(secondResponse.approvedBy, user.username)
            XCTAssertNotNil(secondResponse.creatorUsername)
            XCTAssertEqual(secondResponse.numberOfVotes, 0)
        } catch {
            XCTFail(error.localizedDescription)
        }
    }

    func testCreateTaskWithXSS() {
        do {
            let subtopic = try Subtopic.create(on: conn)
            let user = try User.create(on: conn)
            let xssData = try FlashCardTask.Create.Data(
                subtopicId: subtopic.requireID(),
                description: "# XSS test<SCRIPT SRC=http://xss.rocks/xss.js></SCRIPT>",
                question: "Some question",
                solution: "<IMG SRC=javascript:alert(&quot;XSS&quot;)>More XSS $$\\frac{1}{2}$$",
                isTestable: false,
                examPaperSemester: nil,
                examPaperYear: nil
            )
            let createData = Task.Create.Data(
                content: xssData,
                subtopicID: xssData.subtopicId,
                solution: xssData.solution
            )
            let task = try Task.Repository.create(from: createData, by: user, on: conn).wait()
            let solution = try XCTUnwrap(TaskSolution.DatabaseRepository.solutions(for: task.requireID(), for: user, on: conn).wait().first)

            XCTAssertEqual(task.description, "# XSS test")
            XCTAssertEqual(solution.solution, "<img>More XSS $$\\frac{1}{2}$$")
        } catch {
            XCTFail(error.localizedDescription)
        }
    }

    static var allTests = [
        ("testTasksInSubject", testTasksInSubject),
        ("testCreateTaskWithXSS", testCreateTaskWithXSS),
        ("testSolutions", testSolutions)
    ]
}
