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

        let task = try Task.create(createSolution: false, on: conn)
        let user = try User.create(on: conn)
        let firstSolution = try TaskSolution.create(task: task, presentUser: false, on: conn)
        let secondSolution = try TaskSolution.create(task: task, on: conn)
        _ = try TaskSolution.create(on: conn)

        secondSolution.isApproved = true
        secondSolution.approvedBy = try user.requireID()
        _ = try secondSolution.save(on: conn).wait()

        let solutions = try TaskSolution.Repository.solutions(for: task.requireID(), on: conn).wait()
        
        XCTAssertEqual(solutions.count, 2)
        XCTAssertNotNil(solutions.first(where: { $0.solution == firstSolution.solution }))
        XCTAssertNil(solutions.first(where: { $0.solution == firstSolution.solution })?.creatorName)
        XCTAssertNil(solutions.first(where: { $0.solution == firstSolution.solution })?.approvedBy)
        XCTAssertNotNil(solutions.first(where: { $0.solution == secondSolution.solution }))
        XCTAssertEqual(solutions.first(where: { $0.solution == secondSolution.solution })?.approvedBy, user.name)
        XCTAssertNotNil(solutions.first(where: { $0.solution == secondSolution.solution })?.creatorName)
    }

    func testSolutionBugFixMigration() throws {
        _ = try Task.create(createSolution: false, on: conn)
        _ = try Task.create(createSolution: false, on: conn)
        _ = try Task.create(createSolution: false, on: conn)
        _ = try Task.create(on: conn)

        let solutionsCount = try TaskSolution.query(on: conn)
            .count()
            .wait()

        XCTAssertEqual(solutionsCount, 1)

        _ = try TaskSolution.Repository
            .createSolutionForOutOfSyncTasks(on: conn)
            .wait()

        let newSolutionsCount = try TaskSolution.query(on: conn)
            .count()
            .wait()

        XCTAssertEqual(newSolutionsCount, 4)
    }

    static var allTests = [
        ("testTasksInSubject", testTasksInSubject),
        ("testSolutions", testSolutions),
        ("testSolutionBugFixMigration", testSolutions),
    ]
}
