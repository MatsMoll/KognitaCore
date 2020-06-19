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

    lazy var taskSolutionRepository: TaskSolutionRepositoring = { TestableRepositories.testable(with: conn).taskSolutionRepository }()
    lazy var taskRepository: TaskRepository = { Task.DatabaseRepository(conn: conn) }()
    lazy var typingTaskRepository: FlashCardTaskRepository = { TestableRepositories.testable(with: conn).typingTaskRepository }()

    func testTasksInSubject() throws {

        let subject = try Subject.create(name: "test", on: conn)
        let topic = try Topic.create(subject: subject, on: conn)
        let subtopic = try Subtopic.create(topic: topic, on: conn)
        _ = try Task.create(subtopic: subtopic, on: conn)
        _ = try Task.create(subtopic: subtopic, on: conn)
        _ = try Task.create(subtopic: subtopic, on: conn)
        _ = try Task.create(subtopic: subtopic, on: conn)
        _ = try Task.create(on: conn)

        let tasks = try taskRepository
            .getTasks(in: subject)
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
            let secondSolutionDB = try TaskSolution.DatabaseModel.find(secondSolution.id, on: conn).unwrap(or: Errors.badTest).wait()
            _ = try TaskSolution.create(on: conn)

            secondSolutionDB.isApproved = true
            secondSolutionDB.approvedBy = user.id
            _ = try secondSolutionDB.save(on: conn).wait()

            try taskSolutionRepository.upvote(for: firstSolution.id, by: user).wait()
            try taskSolutionRepository.upvote(for: firstSolution.id, by: secondUser).wait()

            let solutions = try taskSolutionRepository.solutions(for: task.requireID(), for: user).wait()

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

    func testCreateTaskWithEmptySolution() {
        failableTest {
            let subtopic = try Subtopic.create(on: conn)
            let user = try User.create(on: conn)
            let xssData = FlashCardTask.Create.Data(
                subtopicId: subtopic.id,
                description: "Test",
                question: "Some question",
                solution: "",
                isTestable: false,
                examPaperSemester: nil,
                examPaperYear: nil
            )
            let createData = Task.Create.Data(
                content: xssData,
                subtopicID: xssData.subtopicId,
                solution: xssData.solution
            )
            XCTAssertThrowsError(try taskRepository.create(from: createData, by: user).wait())
        }
    }

    func testCreateMultipleLineSolution() {
        failableTest {
            let subtopic = try Subtopic.create(on: conn)
            let user = try User.create(on: conn)
            let xssData = FlashCardTask.Create.Data(
                subtopicId: subtopic.id,
                description: "Test",
                question: "Some question",
                solution:
"""
Hallo

Dette er flere linjer
""",
                isTestable: false,
                examPaperSemester: nil,
                examPaperYear: nil
            )
            let createData = Task.Create.Data(
                content: xssData,
                subtopicID: xssData.subtopicId,
                solution: xssData.solution
            )
            let task = try taskRepository.create(from: createData, by: user).wait()
            let solution = try XCTUnwrap(taskSolutionRepository.solutions(for: task.requireID(), for: user).wait().first)

            XCTAssertEqual(solution.solution, "Hallo\n\nDette er flere linjer")
        }
    }

    func testCreateTaskWithXSS() {
        do {
            let subtopic = try Subtopic.create(on: conn)
            let user = try User.create(on: conn)
            let xssData = FlashCardTask.Create.Data(
                subtopicId: subtopic.id,
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
            let task = try taskRepository.create(from: createData, by: user).wait()
            let solution = try XCTUnwrap(taskSolutionRepository.solutions(for: task.requireID(), for: user).wait().first)

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
            let xssData = FlashCardTask.Create.Data(
                subtopicId: subtopic.id,
                description: "# XSS test<SCRIPT SRC=http://xss.rocks/xss.js></SCRIPT>",
                question: "Some question",
                solution: "<IMG SRC=javascript:alert(&quot;XSS&quot;)>More XSS $$\\frac{1}{2}$$",
                isTestable: false,
                examPaperSemester: nil,
                examPaperYear: nil
            )
            let task = try typingTaskRepository.create(from: xssData, by: user).wait()
            let flashCardTask = try FlashCardTask.find(task.requireID(), on: conn).unwrap(or: Errors.badTest).wait()
            let solution = try XCTUnwrap(taskSolutionRepository.solutions(for: task.requireID(), for: user).wait().first)

            XCTAssertEqual(task.description, "# XSS test")
            XCTAssertEqual(solution.solution, "<img>More XSS $$\\frac{1}{2}$$")

            let updatedTask = try typingTaskRepository.updateModelWith(id: flashCardTask.id!, to: xssData, by: user).wait()
            let updatedSolution = try XCTUnwrap(taskSolutionRepository.solutions(for: task.requireID(), for: user).wait().first)

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
            let xssData = FlashCardTask.Create.Data(
                subtopicId: subtopic.id,
                description: "# XSS test<SCRIPT SRC=http://xss.rocks/xss.js></SCRIPT>",
                question: "Some question",
                solution: "<IMG SRC=javascript:alert(&quot;XSS&quot;)>More XSS $$\\frac{1}{2}$$",
                isTestable: false,
                examPaperSemester: nil,
                examPaperYear: nil
            )
            let task = try typingTaskRepository.create(from: xssData, by: user).wait()

            let solutionUpdateDate = TaskSolution.Update.Data(
                solution: #"<IMG """><SCRIPT>alert("XSS")</SCRIPT>"\> Hello"#,
                presentUser: false
            )
            let solution = try TaskSolution.DatabaseModel.query(on: conn).filter(\.taskID == task.requireID()).first().unwrap(or: Errors.badTest).wait()
            _ = try taskSolutionRepository.updateModelWith(id: solution.id!, to: solutionUpdateDate, by: user).wait()
            let updatedSolution = try TaskSolution.DatabaseModel.query(on: conn).filter(\.taskID == task.requireID()).first().unwrap(or: Errors.badTest).wait()

            XCTAssertEqual(updatedSolution.solution, #"<img>"\&gt; Hello"#)
        } catch {
            XCTFail(error.localizedDescription)
        }
    }

    func testSolutionsCascadeDelete() {
        do {
            let task = try Task.create(on: conn)
            let user = try User.create(on: conn)
            let solutions = try taskSolutionRepository.solutions(for: task.requireID(), for: user).wait()
            XCTAssertEqual(solutions.count, 1)
            try task.delete(force: true, on: conn).wait()
            let newSolution = try taskSolutionRepository.solutions(for: task.requireID(), for: user).wait()
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

            var solutions = try taskSolutionRepository.solutions(for: task.requireID(), for: user).wait()
            var solution = try XCTUnwrap(solutions.first)
            XCTAssertNil(solution.approvedBy)

            try taskSolutionRepository.approve(for: solution.id, by: user).wait()
            solutions = try taskSolutionRepository.solutions(for: task.requireID(), for: user).wait()
            solution = try XCTUnwrap(solutions.first)

            XCTAssertEqual(solution.approvedBy, user.username)
        }
    }

    func testApproveSolutionUnauthorized() {
        failableTest {
            let user = try User.create(isAdmin: false, on: conn)
            let task = try Task.create(creator: user, on: conn)

            var solutions = try taskSolutionRepository.solutions(for: task.requireID(), for: user).wait()
            var solution = try XCTUnwrap(solutions.first)
            XCTAssertNil(solution.approvedBy)

            XCTAssertThrowsError(try taskSolutionRepository.approve(for: solution.id, by: user).wait())
            solutions = try taskSolutionRepository.solutions(for: task.requireID(), for: user).wait()
            solution = try XCTUnwrap(solutions.first)

            XCTAssertNil(solution.approvedBy)
        }
    }

    func testDeleteSolution() {
        failableTest {
            let user = try User.create(on: conn)
            let task = try Task.create(on: conn)

            let solutions = try TaskSolution.DatabaseModel.query(on: conn).filter(\.taskID == task.requireID()).all().wait()

            XCTAssertEqual(solutions.count, 1)
            let solution = try XCTUnwrap(solutions.first)

            throwsError(of: TaskSolutionRepositoryError.self) {
                try taskSolutionRepository.deleteModelWith(id: solution.id!, by: user).wait()
            }
            throwsError(of: Abort.self) {
                try taskSolutionRepository.deleteModelWith(id: solution.id!, by: nil).wait()
            }
        }
    }

    static var allTests = [
        ("testTasksInSubject", testTasksInSubject),
        ("testCreateTaskWithEmptySolution", testCreateTaskWithEmptySolution),
        ("testCreateTaskWithXSS", testCreateTaskWithXSS),
        ("testUpdateTaskXSS", testUpdateTaskXSS),
        ("testUpdateSolutionXSS", testUpdateSolutionXSS),
        ("testSolutions", testSolutions),
        ("testSolutionsCascadeDelete", testSolutionsCascadeDelete),
        ("testApproveSolution", testApproveSolution),
        ("testApproveSolutionUnauthorized", testApproveSolutionUnauthorized),
        ("testCreateMultipleLineSolution", testCreateMultipleLineSolution),
        ("testDeleteSolution", testDeleteSolution)
    ]
}
