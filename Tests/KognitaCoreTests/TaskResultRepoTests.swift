//
//  TaskResultRepoTests.swift
//  KognitaCoreTests
//
//  Created by Mats Mollestad on 30/04/2019.
//

import Vapor
import XCTest
import FluentPostgreSQL
import KognitaCore
import KognitaCoreTestable

class TaskResultRepoTests: VaporTestCase {

    func testHistogramRoute() throws {

        let user = try User.create(on: conn)
        let subject = try Subject.create(name: "test", on: conn)
        let topic = try Topic.create(subject: subject, on: conn)
        let subtopic = try Subtopic.create(topic: topic, on: conn)
        let taskOne = try Task.create(subtopic: subtopic, on: conn)
        let taskTwo = try Task.create(subtopic: subtopic, on: conn)

        let sessionOne = try PracticeSession.create(in: [subtopic.requireID()], for: user, on: conn)
        let sessionTwo = try PracticeSession.create(in: [subtopic.requireID()], for: user, on: conn)

        _ = try TaskResult.create(task: taskOne, session: sessionOne, user: user, on: conn)
        _ = try TaskResult.create(task: taskTwo, session: sessionOne, user: user, on: conn)
        _ = try TaskResult.create(task: taskOne, session: sessionTwo, user: user, on: conn)
        _ = try TaskResult.create(task: taskTwo, session: sessionTwo, user: user, on: conn)

        let histogram = try TaskResultRepository
            .getAmountHistory(for: user, on: conn)
            .wait()
        XCTAssertEqual(histogram.count, 7)
        // A local bug groupes it in the second day sometimes
        XCTAssertTrue(histogram.last?.numberOfTasksCompleted == 4 || histogram[5].numberOfTasksCompleted == 4)
    }

    func testFlowZoneTasks() throws {
        let user = try User.create(on: conn)
        let subject = try Subject.create(name: "test", on: conn)
        let topic = try Topic.create(subject: subject, on: conn)
        let subtopic = try Subtopic.create(topic: topic, on: conn)
        let taskOne = try Task.create(subtopic: subtopic, on: conn)
        let taskTwo = try Task.create(subtopic: subtopic, on: conn)

        let lastSession = try PracticeSession.create(in: [subtopic.requireID()], for: user, on: conn)
        let newSession = try PracticeSession.create(in: [subtopic.requireID()], for: user, on: conn)

        let taskType = try TaskResultRepository.getFlowZoneTasks(for: newSession, on: conn).wait()
        XCTAssertNil(taskType)

        _ = try TaskResult.create(task: taskOne, session: lastSession, user: user, score: 0.4,  on: conn)
        _ = try TaskResult.create(task: taskTwo, session: lastSession, user: user, score: 0.6,  on: conn)

        let taskTypeOne = try TaskResultRepository.getFlowZoneTasks(for: newSession, on: conn).wait()
        XCTAssertNotNil(taskTypeOne)
        XCTAssertEqual(taskTypeOne?.taskID, taskTwo.id)

        _ = try TaskResult.create(task: taskTwo, session: newSession, user: user, score: 0.5,    on: conn)
        let taskTypeTwo = try TaskResultRepository.getFlowZoneTasks(for: newSession, on: conn).wait()

        XCTAssertNotNil(taskTypeTwo)
        XCTAssertEqual(taskTypeTwo?.taskID, taskOne.id)
    }

    static var allTests = [
        ("testHistogramRoute", testHistogramRoute),
        ("testFlowZoneTasks", testFlowZoneTasks)
    ]
}
