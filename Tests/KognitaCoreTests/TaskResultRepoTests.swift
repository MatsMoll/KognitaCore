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

        _ = try TaskResult.create(task: taskOne, sessionID: sessionOne.requireID(), user: user, on: conn)
        _ = try TaskResult.create(task: taskTwo, sessionID: sessionOne.requireID(), user: user, on: conn)
        _ = try TaskResult.create(task: taskOne, sessionID: sessionTwo.requireID(), user: user, on: conn)
        _ = try TaskResult.create(task: taskTwo, sessionID: sessionTwo.requireID(), user: user, on: conn)

        let firstHistogram = try TaskResult.DatabaseRepository
            .getAmountHistory(for: user, on: conn)
            .wait()
        let secondHistogram = try TaskResult.DatabaseRepository
            .getAmountHistory(for: user, on: conn, numberOfWeeks: 7)
            .wait()

        XCTAssertEqual(firstHistogram.count, 4)
        // A local bug groupes it in the second day sometimes
        XCTAssertTrue(firstHistogram.last?.numberOfTasksCompleted == 4)

        XCTAssertEqual(secondHistogram.count, 7)
        // A local bug groupes it in the second day sometimes
        XCTAssertTrue(secondHistogram.last?.numberOfTasksCompleted == 4)
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

        let taskType = try TaskResult.DatabaseRepository.getFlowZoneTasks(for: newSession, on: conn).wait()
        XCTAssertNil(taskType)

        _ = try TaskResult.create(task: taskOne, sessionID: lastSession.requireID(), user: user, score: 0.4,  on: conn)
        _ = try TaskResult.create(task: taskTwo, sessionID: lastSession.requireID(), user: user, score: 0.6,  on: conn)

        let taskTypeOne = try TaskResult.DatabaseRepository.getFlowZoneTasks(for: newSession, on: conn).wait()
        XCTAssertNotNil(taskTypeOne)
        XCTAssertEqual(taskTypeOne?.taskID, taskTwo.id)

        _ = try TaskResult.create(task: taskTwo, sessionID: newSession.requireID(), user: user, score: 0.5,    on: conn)
        let taskTypeTwo = try TaskResult.DatabaseRepository.getFlowZoneTasks(for: newSession, on: conn).wait()

        XCTAssertNotNil(taskTypeTwo)
        XCTAssertEqual(taskTypeTwo?.taskID, taskOne.id)
    }

    static var allTests = [
        ("testHistogramRoute", testHistogramRoute),
        ("testFlowZoneTasks", testFlowZoneTasks)
    ]
}
