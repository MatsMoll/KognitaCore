//
//  TopicTests.swift
//  AppTests
//
//  Created by Mats Mollestad on 11/10/2018.
//

import XCTest
import Vapor
@testable import KognitaCore
import KognitaCoreTestable

class TopicTests: VaporTestCase {

    lazy var topicRepository: TopicRepository = { TestableRepositories.testable(with: database).topicRepository }()
    lazy var subtopicRepository: SubtopicRepositoring = { TestableRepositories.testable(with: database).subtopicRepository }()

    func testCreate() throws {

        let user = try User.create(on: app)
        let subject = try Subject.create(on: app)

        let topicData = Topic.Create.Data(
            subjectID: subject.id,
            name: "Test",
            chapter: 1
        )

        let topic = try topicRepository
            .create(from: topicData, by: user)
            .wait()
        let subtopics = try subtopicRepository
            .getSubtopics(in: topic)
            .wait()

        XCTAssertEqual(topic.name, topicData.name)
        XCTAssertEqual(topic.subjectID, topicData.subjectID)
        XCTAssertEqual(topic.chapter, topicData.chapter)
        XCTAssertEqual(topic.name, topicData.name)
        XCTAssertEqual(subtopics.count, 1)
        XCTAssertEqual(subtopics.first?.name, "Generelt")
    }

//    func testTimlyTopics() throws {
//
//        let subtopic = try Subtopic.create(on: app)
//
//        _ = try Topic.create(on: app)
//
//        _ = try Task.create(on: app)
//        _ = try Task.create(on: app)
//
//        _ = try Task.create(subtopic: subtopic, on: app)
//        _ = try Task.create(subtopic: subtopic, on: app)
//        _ = try Task.create(subtopic: subtopic, on: app)
//        let outdated = try Task.create(subtopic: subtopic, on: app)
//        _ = try outdated.delete(on: app).wait()
//
//        let timely = try topicRepository
//            .timelyTopics()
//            .wait()
//
//        XCTAssertEqual(timely.count, 4)
//        XCTAssertTrue(timely.contains(where: { $0.numberOfTasks == 3 }))
//        XCTAssertTrue(timely.contains(where: { $0.numberOfTasks == 0 }))
//    }

    func testSoftDelete() throws {
        let subtopic = try Subtopic.create(on: app)

        _ = try Subtopic.create(on: app)

        _ = try TaskDatabaseModel.create(on: app)
        _ = try TaskDatabaseModel.create(on: app)

        _ = try TaskDatabaseModel.create(subtopic: subtopic, on: app)
        let outdated = try TaskDatabaseModel.create(subtopic: subtopic, on: app)
        _ = try outdated.delete(on: database)
            .wait()

        let allValidTasks = try TaskDatabaseModel.query(on: database).all().wait()
        let allTasks = try TaskDatabaseModel.query(on: database).withDeleted().all().wait()

        XCTAssertEqual(allValidTasks.count, 3)
        XCTAssertEqual(allTasks.count, 4)
    }

//    func testLeveledTopics() throws {
//
//        let subject = try Subject.create(on: app)
//
//        let topicOne = try Topic.create(chapter: 1, subject: subject, on: app)
//        let topicTwo = try Topic.create(chapter: 2, subject: subject, on: app)
//        let topicThree = try Topic.create(chapter: 3, subject: subject, on: app)
//        let topicFour = try Topic.create(chapter: 4, subject: subject, on: app)
//        let topicFive = try Topic.create(chapter: 6, subject: subject, on: app)
//
//        _ = try Topic.Pivot.Preknowleged.create(topic: topicOne, requires: topicTwo, on: app).wait()
//        _ = try Topic.Pivot.Preknowleged.create(topic: topicTwo, requires: topicThree, on: app).wait()
//        _ = try Topic.Pivot.Preknowleged.create(topic: topicOne, requires: topicThree, on: app).wait()
//        _ = try Topic.Pivot.Preknowleged.create(topic: topicFour, requires: topicTwo, on: app).wait()
//
//        let levels = try Topic.Repository.leveledTopics(in: subject, on: app).wait()
//
//        XCTAssertEqual(levels.count, 3)
//        XCTAssertEqual(levels.first?.count, 2)
//        try! XCTAssertEqual(Set(levels.first?.map { try $0.requireID() } ?? []), Set([topicFive.requireID(), topicThree.requireID()]))
//        XCTAssertEqual(levels.last?.count, 2)
//    }

    static let allTests = [
        ("testCreate", testCreate),
//        ("testTimlyTopics", testTimlyTopics),
        ("testSoftDelete", testSoftDelete)
//        ("testLeveledTopics", testLeveledTopics)
    ]
}
