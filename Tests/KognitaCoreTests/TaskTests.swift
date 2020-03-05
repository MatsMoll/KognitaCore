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
            XCTAssertNil(firstResponse.creatorUsername)
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

    static var allTests = [
        ("testTasksInSubject", testTasksInSubject),
        ("testSolutions", testSolutions)
    ]
}
