//
//  TopicTests.swift
//  AppTests
//
//  Created by Mats Mollestad on 11/10/2018.
//

import XCTest
import Vapor
import FluentPostgreSQL
@testable import KognitaCore

class TopicTests: VaporTestCase {

    func testCreate() throws {

        let user = try User.create(on: conn)
        let subject = try Subject.create(on: conn)

        let topicData = try Topic.Create.Data(
            subjectId: subject.requireID(),
            name: "Test",
            chapter: 1
        )

        let topic = try Topic.DatabaseRepository
            .create(from: topicData, by: user, on: conn)
            .wait()
        let subtopics = try Subtopic.DatabaseRepository
            .getSubtopics(in: topic, with: conn)
            .wait()

        XCTAssertEqual(topic.name, topicData.name)
        XCTAssertEqual(topic.subjectId, topicData.subjectId)
        XCTAssertEqual(topic.chapter, topicData.chapter)
        XCTAssertEqual(topic.name, topicData.name)
        XCTAssertEqual(subtopics.count, 1)
        XCTAssertEqual(subtopics.first?.name, "Generelt")
    }

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

        let timely = try Topic.DatabaseRepository
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

//    func testLeveledTopics() throws {
//
//        let subject = try Subject.create(on: conn)
//
//        let topicOne = try Topic.create(chapter: 1, subject: subject, on: conn)
//        let topicTwo = try Topic.create(chapter: 2, subject: subject, on: conn)
//        let topicThree = try Topic.create(chapter: 3, subject: subject, on: conn)
//        let topicFour = try Topic.create(chapter: 4, subject: subject, on: conn)
//        let topicFive = try Topic.create(chapter: 6, subject: subject, on: conn)
//
//        _ = try Topic.Pivot.Preknowleged.create(topic: topicOne, requires: topicTwo, on: conn).wait()
//        _ = try Topic.Pivot.Preknowleged.create(topic: topicTwo, requires: topicThree, on: conn).wait()
//        _ = try Topic.Pivot.Preknowleged.create(topic: topicOne, requires: topicThree, on: conn).wait()
//        _ = try Topic.Pivot.Preknowleged.create(topic: topicFour, requires: topicTwo, on: conn).wait()
//
//        let levels = try Topic.Repository.leveledTopics(in: subject, on: conn).wait()
//
//        XCTAssertEqual(levels.count, 3)
//        XCTAssertEqual(levels.first?.count, 2)
//        try! XCTAssertEqual(Set(levels.first?.map { try $0.requireID() } ?? []), Set([topicFive.requireID(), topicThree.requireID()]))
//        XCTAssertEqual(levels.last?.count, 2)
//    }

    static let allTests = [
        ("testCreate", testCreate),
        ("testTimlyTopics", testTimlyTopics),
        ("testSoftDelete", testSoftDelete)
//        ("testLeveledTopics", testLeveledTopics)
    ]
}
