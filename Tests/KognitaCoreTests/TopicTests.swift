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

        let topic = try Topic.create(on: conn)

        _ = try Topic.create(on: conn)

        _ = try Task.create(on: conn)
        _ = try Task.create(on: conn)

        _ = try Task.create(topic: topic, on: conn)
        _ = try Task.create(topic: topic, on: conn)
        _ = try Task.create(topic: topic, on: conn)
        let outdated = try Task.create(topic: topic, on: conn)
        outdated.isOutdated = true
        _ = try outdated.save(on: conn).wait()

        let timely = try TopicRepository.shared
            .timelyTopics(on: conn)
            .wait()

        XCTAssertEqual(timely.count, 4)
        XCTAssertTrue(timely.contains(where: { $0.numberOfTasks == 3 }))
        XCTAssertTrue(timely.contains(where: { $0.numberOfTasks == 0 }))
    }

    static let allTests = [
        ("testTimlyTopics", testTimlyTopics)
    ]
}
