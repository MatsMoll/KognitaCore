//
//  TaskTests.swift
//  App
//
//  Created by Mats Mollestad on 09/11/2018.
//

import Vapor
import XCTest
@testable import KognitaCore
import KognitaCoreTestable

class TaskTests: VaporTestCase {

    lazy var taskResultRepository: TaskResultRepositoring = { TestableRepositories.testable(with: app).taskResultRepository }()
    lazy var taskSolutionRepository: TaskSolutionRepositoring = { TestableRepositories.testable(with: app).taskSolutionRepository }()
    lazy var taskRepository: TaskRepository = { TaskDatabaseModel.DatabaseRepository(database: database, repositories: TestableRepositories.testable(with: app)) }()
    lazy var typingTaskRepository: TypingTaskRepository = { TestableRepositories.testable(with: app).typingTaskRepository }()

    func testTasksInSubject() throws {

        let user = try User.create(on: app)
        let subject = try Subject.create(name: "test", on: app)
        let topic = try Topic.create(subject: subject, on: app)
        let subtopic = try Subtopic.create(topic: topic, on: app)

        _ = try TaskDatabaseModel.create(subtopic: subtopic, on: app)
        _ = try TaskDatabaseModel.create(subtopic: subtopic, on: app)
        _ = try TaskDatabaseModel.create(subtopic: subtopic, on: app)
        _ = try TaskDatabaseModel.create(subtopic: subtopic, on: app)
        _ = try TaskDatabaseModel.create(on: app)

        let tasks = try taskRepository
            .getTasks(in: subject.id, user: user, query: nil, maxAmount: nil, withSoftDeleted: false)
            .wait()
        XCTAssertEqual(tasks.count, 4)
    }

    func testSolutions() throws {
        let task = try TaskDatabaseModel.create(createSolution: false, on: app)
        let user = try User.create(on: app)
        let secondUser = try User.create(isAdmin: false, on: app)
        let firstSolution = try TaskSolution.create(task: task, presentUser: false, on: app)
        let secondSolution = try TaskSolution.create(task: task, on: app)
        let secondSolutionDB = try TaskSolution.DatabaseModel.find(secondSolution.id, on: database).unwrap(or: Errors.badTest).wait()
        _ = try TaskSolution.create(on: app)

        secondSolutionDB.isApproved = true
        secondSolutionDB.$approvedBy.id = user.id
        _ = try secondSolutionDB.save(on: database).wait()

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
    }

    func testCreateTaskWithEmptySolution() throws {
        let subtopic = try Subtopic.create(on: app)
        let user = try User.create(on: app)
        let xssData = TypingTask.Create.Data(
            subtopicId: subtopic.id,
            description: "Test",
            question: "Some question",
            solution: "",
            isTestable: false,
            examID: nil
        )
        let createData = TaskDatabaseModel.Create.Data(
            content: xssData,
            subtopicID: xssData.subtopicId,
            solution: xssData.solution
        )
        XCTAssertThrowsError(try taskRepository.create(from: createData, by: user).wait())
    }

    func testCreateMultipleLineSolution() throws {
        let subtopic = try Subtopic.create(on: app)
        let user = try User.create(on: app)
        let xssData = TypingTask.Create.Data(
            subtopicId: subtopic.id,
            description: "Test",
            question: "Some question",
            solution:
"""
Hallo

Dette er flere linjer
""",
            isTestable: false,
            examID: nil
        )
        let createData = TaskDatabaseModel.Create.Data(
            content: xssData,
            subtopicID: xssData.subtopicId,
            solution: xssData.solution
        )
        let task = try taskRepository.create(from: createData, by: user).wait()
        let solution = try XCTUnwrap(taskSolutionRepository.solutions(for: task.requireID(), for: user).wait().first)

        XCTAssertEqual(solution.solution, "Hallo\n\nDette er flere linjer")
    }

    func testCreateTaskWithXSS() throws {
        let subtopic = try Subtopic.create(on: app)
        let user = try User.create(on: app)
        let xssData = TypingTask.Create.Data(
            subtopicId: subtopic.id,
            description: "# XSS test<SCRIPT SRC=http://xss.rocks/xss.js></SCRIPT>",
            question: "Some question",
            solution: "<IMG SRC=javascript:alert(&quot;XSS&quot;)>More XSS $$\\frac{1}{2}$$",
            isTestable: false,
            examID: nil
        )
        let createData = TaskDatabaseModel.Create.Data(
            content: xssData,
            subtopicID: xssData.subtopicId,
            solution: xssData.solution
        )
        let task = try taskRepository.create(from: createData, by: user).wait()
        let solution = try XCTUnwrap(taskSolutionRepository.solutions(for: task.requireID(), for: user).wait().first)

        XCTAssertEqual(task.$description.value, "# XSS test")
        XCTAssertEqual(solution.solution, "<img>More XSS $$\\frac{1}{2}$$")
    }

    func testUpdateTaskXSS() throws {
        let subtopic = try Subtopic.create(on: app)
        let user = try User.create(on: app)
        let xssData = TypingTask.Create.Data(
            subtopicId: subtopic.id,
            description: "# XSS test<SCRIPT SRC=http://xss.rocks/xss.js></SCRIPT>",
            question: "Some question",
            solution: "<IMG SRC=javascript:alert(&quot;XSS&quot;)>More XSS $$\\frac{1}{2}$$",
            isTestable: false,
            examID: nil
        )
        let task = try typingTaskRepository.create(from: xssData, by: user).wait()
        let flashCardTask = try FlashCardTask.find(task.id, on: database).unwrap(or: Errors.badTest).wait()
        let solution = try XCTUnwrap(taskSolutionRepository.solutions(for: task.id, for: user).wait().first)

        XCTAssertEqual(task.description, "# XSS test")
        XCTAssertEqual(solution.solution, "<img>More XSS $$\\frac{1}{2}$$")

        let updatedTask = try typingTaskRepository.updateModelWith(id: flashCardTask.id!, to: xssData, by: user).wait()
        let updatedSolution = try XCTUnwrap(taskSolutionRepository.solutions(for: task.id, for: user).wait().first)

        XCTAssertEqual(updatedTask.description, "# XSS test")
        XCTAssertEqual(updatedSolution.solution, "<img>More XSS $$\\frac{1}{2}$$")
    }

    func testUpdateSolutionXSS() throws {
        let subtopic = try Subtopic.create(on: app)
        let user = try User.create(on: app)
        let xssData = TypingTask.Create.Data(
            subtopicId: subtopic.id,
            description: "# XSS test<SCRIPT SRC=http://xss.rocks/xss.js></SCRIPT>",
            question: "Some question",
            solution: "<IMG SRC=javascript:alert(&quot;XSS&quot;)>More XSS $$\\frac{1}{2}$$",
            isTestable: false,
            examID: nil
        )
        let task = try typingTaskRepository.create(from: xssData, by: user).wait()

        let solutionUpdateDate = TaskSolution.Update.Data(
            solution: #"<IMG """><SCRIPT>alert("XSS")</SCRIPT>"\> Hello"#,
            presentUser: false
        )
        let solution = try TaskSolution.DatabaseModel.query(on: database).filter(\.$task.$id == task.id).first().unwrap(or: Errors.badTest).wait()
        _ = try taskSolutionRepository.updateModelWith(id: solution.id!, to: solutionUpdateDate, by: user).wait()
        let updatedSolution = try TaskSolution.DatabaseModel.query(on: database).filter(\.$task.$id == task.id).first().unwrap(or: Errors.badTest).wait()

        XCTAssertEqual(updatedSolution.solution, #"<img>"\&gt; Hello"#)
    }

    func testSolutionsCascadeDelete() throws {
        let task = try TaskDatabaseModel.create(on: app)
        let user = try User.create(on: app)
        let solutions = try taskSolutionRepository.solutions(for: task.requireID(), for: user).wait()
        XCTAssertEqual(solutions.count, 1)
        try task.delete(force: true, on: database).wait()
        let newSolution = try taskSolutionRepository.solutions(for: task.requireID(), for: user).wait()
        XCTAssertEqual(newSolution.count, 0)
    }

    func testApproveSolution() throws {
        let user = try User.create(on: app)
        let unauthorizedUser = try User.create(isAdmin: false, on: app)
        let task = try TaskDatabaseModel.create(creator: unauthorizedUser, on: app)

        var solutions = try taskSolutionRepository.solutions(for: task.requireID(), for: user).wait()
        var solution = try XCTUnwrap(solutions.first)
        XCTAssertNil(solution.approvedBy)

        try taskSolutionRepository.approve(for: solution.id, by: user).wait()
        solutions = try taskSolutionRepository.solutions(for: task.requireID(), for: user).wait()
        solution = try XCTUnwrap(solutions.first)

        XCTAssertEqual(solution.approvedBy, user.username)
    }

    func testApproveSolutionUnauthorized() throws {
        let user = try User.create(isAdmin: false, on: app)
        let task = try TaskDatabaseModel.create(creator: user, on: app)

        var solutions = try taskSolutionRepository.solutions(for: task.requireID(), for: user).wait()
        var solution = try XCTUnwrap(solutions.first)
        XCTAssertNil(solution.approvedBy)

        XCTAssertThrowsError(try taskSolutionRepository.approve(for: solution.id, by: user).wait())
        solutions = try taskSolutionRepository.solutions(for: task.requireID(), for: user).wait()
        solution = try XCTUnwrap(solutions.first)

        XCTAssertNil(solution.approvedBy)
    }

    func testDeleteSolution() throws {
        let user = try User.create(on: app)
        let task = try TaskDatabaseModel.create(on: app)

        let solutions = try TaskSolution.DatabaseModel.query(on: database).filter(\.$task.$id == task.requireID()).all().wait()

        XCTAssertEqual(solutions.count, 1)
        let solution = try XCTUnwrap(solutions.first)

        throwsError(of: TaskSolutionRepositoryError.self) {
            try taskSolutionRepository.deleteModelWith(id: solution.id!, by: user).wait()
        }
        throwsError(of: Abort.self) {
            try taskSolutionRepository.deleteModelWith(id: solution.id!, by: nil).wait()
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
