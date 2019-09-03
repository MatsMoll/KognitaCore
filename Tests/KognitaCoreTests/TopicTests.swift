//
//  TopicTests.swift
//  AppTests
//
//  Created by Mats Mollestad on 11/10/2018.
//

import XCTest
import Vapor
import FluentPostgreSQL
import KognitaCore


class TopicTests: VaporTestCase {

    func testTimlyTopics() throws {

        let subtopic = try Subtopic.create(on: conn)

        _ = try Topic.create(on: conn)

        _ = try Task.create(on: conn)
        _ = try Task.create(on: conn)

        _ = try Task.create(subtopic: subtopic, on: conn)
        _ = try Task.create(subtopic: subtopic, on: conn)
        _ = try Task.create(subtopic: subtopic, on: conn)
        let outdated = try Task.create(subtopic: subtopic, on: conn)
        _ = try outdated.delete(on: conn).wait()

        let timely = try Topic.Repository.shared
            .timelyTopics(on: conn)
            .wait()

        XCTAssertEqual(timely.count, 4)
        XCTAssertTrue(timely.contains(where: { $0.numberOfTasks == 3 }))
        XCTAssertTrue(timely.contains(where: { $0.numberOfTasks == 0 }))
    }

    func testSoftDelete() throws {
        let subtopic = try Subtopic.create(on: conn)

        _ = try Subtopic.create(on: conn)

        _ = try Task.create(on: conn)
        _ = try Task.create(on: conn)

        _ = try Task.create(subtopic: subtopic, on: conn)
        let outdated = try Task.create(subtopic: subtopic, on: conn)
        _ = try outdated.delete(on: conn)
            .wait()

        let allValidTasks = try Task.query(on: conn).all().wait()
        let allTasks = try Task.query(on: conn, withSoftDeleted: true).all().wait()

        XCTAssertEqual(allValidTasks.count, 3)
        XCTAssertEqual(allTasks.count, 4)
    }

    static let allTests = [
        ("testTimlyTopics", testTimlyTopics),
        ("testSoftDelete", testSoftDelete)
    ]
}
