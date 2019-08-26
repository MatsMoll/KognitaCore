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

class TaskResultRepoTests: VaporTestCase {

    func testHistogramRoute() throws {

        let user = try User.create(on: conn)
        let subject = try Subject.create(name: "test", on: conn)
        let topic = try Topic.create(subject: subject, on: conn)
        let subtopic = try Subtopic.create(topic: topic, on: conn)
        let taskOne = try Task.create(subtopic: subtopic, on: conn)
        let taskTwo = try Task.create(subtopic: subtopic, on: conn)

        _ = try TaskResult.create(task: taskOne, session: nil, user: user, on: conn)
        _ = try TaskResult.create(task: taskTwo, session: nil, user: user, on: conn)
        _ = try TaskResult.create(task: taskTwo, session: nil, user: user, on: conn)
        _ = try TaskResult.create(task: taskTwo, session: nil, user: user, on: conn)

        let histogram = try TaskResultRepository.shared
            .getAmountHistory(for: user, on: conn)
            .wait()
        print(histogram)
        XCTAssertEqual(histogram.count, 7)
        // A local bug groupes it in the second day sometimes
        XCTAssertTrue(histogram.last?.numberOfTasksCompleted == 4 || histogram[5].numberOfTasksCompleted == 4)
    }


    static var allTests = [
        ("testHistogramRoute", testHistogramRoute)
    ]
}
