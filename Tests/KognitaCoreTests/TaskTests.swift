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

    func testUpdateTaskXSS() {
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
            let task = try FlashCardTask.DatabaseRepository.create(from: xssData, by: user, on: conn).wait()
            let flashCardTask = try FlashCardTask.find(task.requireID(), on: conn).unwrap(or: Errors.badTest).wait()
            let solution = try XCTUnwrap(TaskSolution.DatabaseRepository.solutions(for: task.requireID(), for: user, on: conn).wait().first)

            XCTAssertEqual(task.description, "# XSS test")
            XCTAssertEqual(solution.solution, "<img>More XSS $$\\frac{1}{2}$$")

            let updatedTask = try FlashCardTask.DatabaseRepository.update(model: flashCardTask, to: xssData, by: user, on: conn).wait()
            let updatedSolution = try XCTUnwrap(TaskSolution.DatabaseRepository.solutions(for: task.requireID(), for: user, on: conn).wait().first)

            XCTAssertEqual(updatedTask.description, "# XSS test")
            XCTAssertEqual(updatedSolution.solution, "<img>More XSS $$\\frac{1}{2}$$")
        } catch {
            XCTFail(error.localizedDescription)
        }
    }

    func testUpdateSolutionXSS() {
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
            let task = try FlashCardTask.DatabaseRepository.create(from: xssData, by: user, on: conn).wait()

            let solutionUpdateDate = TaskSolution.Update.Data(
                solution: #"<IMG """><SCRIPT>alert("XSS")</SCRIPT>"\> Hello"#,
                presentUser: false
            )
            let solution = try TaskSolution.query(on: conn).filter(\.taskID == task.requireID()).first().unwrap(or: Errors.badTest).wait()
            _ = try TaskSolution.DatabaseRepository.update(model: solution, to: solutionUpdateDate, by: user, on: conn).wait()
            let updatedSolution = try TaskSolution.query(on: conn).filter(\.taskID == task.requireID()).first().unwrap(or: Errors.badTest).wait()

            XCTAssertEqual(updatedSolution.solution, #"<img>"\&gt; Hello"#)
        } catch {
            XCTFail(error.localizedDescription)
        }
    }

    func testSolutionsCascadeDelete() {
        do {
            let task = try Task.create(on: conn)
            let user = try User.create(on: conn)
            let solutions = try TaskSolution.DatabaseRepository.solutions(for: task.requireID(), for: user, on: conn).wait()
            XCTAssertEqual(solutions.count, 1)
            try task.delete(force: true, on: conn).wait()
            let newSolution = try TaskSolution.DatabaseRepository.solutions(for: task.requireID(), for: user, on: conn).wait()
            XCTAssertTrue(newSolution.isEmpty)
        } catch {
            XCTFail(error.localizedDescription)
        }
    }

    func testApproveSolution() {
        failableTest {
            let user = try User.create(on: conn)
            let unauthorizedUser = try User.create(isAdmin: false, on: conn)
            let task = try Task.create(creator: unauthorizedUser, on: conn)

            var solutions = try TaskSolution.DatabaseRepository.solutions(for: task.requireID(), for: user, on: conn).wait()
            var solution = try XCTUnwrap(solutions.first)
            XCTAssertNil(solution.approvedBy)

            try TaskSolution.DatabaseRepository.approve(for: solution.id, by: user, on: conn).wait()
            solutions = try TaskSolution.DatabaseRepository.solutions(for: task.requireID(), for: user, on: conn).wait()
            solution = try XCTUnwrap(solutions.first)

            XCTAssertEqual(solution.approvedBy, user.username)
        }
    }

    func testApproveSolutionUnauthorized() {
        failableTest {
            let user = try User.create(isAdmin: false, on: conn)
            let task = try Task.create(creator: user, on: conn)

            var solutions = try TaskSolution.DatabaseRepository.solutions(for: task.requireID(), for: user, on: conn).wait()
            var solution = try XCTUnwrap(solutions.first)
            XCTAssertNil(solution.approvedBy)

            XCTAssertThrowsError(try TaskSolution.DatabaseRepository.approve(for: solution.id, by: user, on: conn).wait())
            solutions = try TaskSolution.DatabaseRepository.solutions(for: task.requireID(), for: user, on: conn).wait()
            solution = try XCTUnwrap(solutions.first)

            XCTAssertNil(solution.approvedBy)
        }
    }

    static var allTests = [
        ("testTasksInSubject", testTasksInSubject),
        ("testCreateTaskWithXSS", testCreateTaskWithXSS),
        ("testUpdateTaskXSS", testUpdateTaskXSS),
        ("testUpdateSolutionXSS", testUpdateSolutionXSS),
        ("testSolutions", testSolutions),
        ("testSolutionsCascadeDelete", testSolutionsCascadeDelete),
        ("testApproveSolution", testApproveSolution),
        ("testApproveSolutionUnauthorized", testApproveSolutionUnauthorized),
    ]
}
