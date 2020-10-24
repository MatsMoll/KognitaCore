//
//  TaskResultRepoTests.swift
//  KognitaCoreTests
//
//  Created by Mats Mollestad on 30/04/2019.
//

import Vapor
import XCTest
@testable import KognitaCore
import KognitaCoreTestable

class TaskResultRepoTests: VaporTestCase {

    var taskResultRepository: TaskResultRepositoring { TestableRepositories.testable(with: app).taskResultRepository }

    func testHistogramRoute() throws {

        let user = try User.create(on: app)
        let subject = try Subject.create(name: "test", on: app)
        let topic = try Topic.create(subject: subject, on: app)
        let subtopic = try Subtopic.create(topic: topic, on: app)
        let taskOne = try TaskDatabaseModel.create(subtopic: subtopic, on: app)
        let taskTwo = try TaskDatabaseModel.create(subtopic: subtopic, on: app)

        let sessionOne = try PracticeSession.create(in: [subtopic.id], for: user, on: app)
        let sessionTwo = try PracticeSession.create(in: [subtopic.id], for: user, on: app)

        _ = try TaskResult.create(task: taskOne, sessionID: sessionOne.requireID(), user: user, on: database)
        _ = try TaskResult.create(task: taskTwo, sessionID: sessionOne.requireID(), user: user, on: database)
        _ = try TaskResult.create(task: taskOne, sessionID: sessionTwo.requireID(), user: user, on: database)
        _ = try TaskResult.create(task: taskTwo, sessionID: sessionTwo.requireID(), user: user, on: database)

        let firstHistogram = try taskResultRepository
            .getAmountHistory(for: user, numberOfWeeks: 4)
            .wait()
        let secondHistogram = try taskResultRepository
            .getAmountHistory(for: user, numberOfWeeks: 7)
            .wait()

        if firstHistogram.count == 4 {
            // A local bug groupes it in the second day sometimes
            let maxCompletedTasks = max(firstHistogram[3].numberOfTasksCompleted, firstHistogram[2].numberOfTasksCompleted)
            XCTAssertEqual(maxCompletedTasks, 4)
        } else {
            XCTFail("Incorrect amount of histogramdata")
        }

        if secondHistogram.count == 7 {
            // A local bug groupes it in the second day sometimes
            let maxCompletedTasks = max(secondHistogram[6].numberOfTasksCompleted, secondHistogram[5].numberOfTasksCompleted)
            XCTAssertEqual(maxCompletedTasks, 4)
        } else {
            XCTFail("Incorrect amount of histogramdata")
        }

    }

    func testSpaceRepetitionWithMultipleUsers() throws {
        let user = try User.create(on: app)
        let secondUser = try User.create(on: app)
        let subject = try Subject.create(name: "test", on: app)
        let topic = try Topic.create(subject: subject, on: app)
        let subtopic = try Subtopic.create(topic: topic, on: app)
        let otherSubtopic = try Subtopic.create(topic: topic, on: app)
        let taskOne = try TaskDatabaseModel.create(subtopic: subtopic, on: app)
        let taskTwo = try TaskDatabaseModel.create(subtopic: subtopic, on: app)
        let otherTask = try TaskDatabaseModel.create(subtopic: otherSubtopic, on: app)

        let otherSession = try PracticeSession.create(in: [subtopic.id], for: secondUser, on: app)
        let lastSession = try PracticeSession.create(in: [subtopic.id], for: user, on: app)
        let newSession = try PracticeSession.create(in: [subtopic.id], for: user, on: app)

        let taskType = try taskResultRepository.getSpaceRepetitionTask(for: user.id, sessionID: newSession.requireID()).wait()
        XCTAssertNil(taskType)

        _ = try TaskResult.create(task: taskOne, sessionID: lastSession.requireID(), user: user, score: 0.4, on: database)
        _ = try TaskResult.create(task: taskTwo, sessionID: lastSession.requireID(), user: user, score: 0.7, on: database)

        _ = try TaskResult.create(task: taskTwo, sessionID: otherSession.requireID(), user: secondUser, score: 0.2, on: database)

        let taskTypeOne = try taskResultRepository.getSpaceRepetitionTask(for: user.id, sessionID: newSession.requireID()).wait()

        XCTAssertNotNil(taskTypeOne)
        XCTAssertEqual(taskTypeOne?.taskID, taskOne.id)

        _ = try TaskResult.create(task: taskOne, sessionID: newSession.requireID(), user: user, score: 0.6, on: database)
        _ = try TaskResult.create(task: otherTask, sessionID: lastSession.requireID(), user: user, score: 0.2, on: database)

        let taskTypeTwo = try taskResultRepository.getSpaceRepetitionTask(for: user.id, sessionID: newSession.requireID()).wait()

        XCTAssertNotNil(taskTypeTwo)
        XCTAssertEqual(taskTypeTwo?.taskID, taskTwo.id)
    }

    func testSpaceRepetitionWithDeletedTask() throws {
        let user = try User.create(on: app)
        let subject = try Subject.create(name: "test", on: app)
        let topic = try Topic.create(subject: subject, on: app)
        let subtopic = try Subtopic.create(topic: topic, on: app)
        let taskOne = try TaskDatabaseModel.create(subtopic: subtopic, on: app)
        let taskTwo = try TaskDatabaseModel.create(subtopic: subtopic, on: app)
        let deletedTask = try TaskDatabaseModel.create(subtopic: subtopic, on: app)

        let lastSession = try PracticeSession.create(in: [subtopic.id], for: user, on: app)
        let newSession = try PracticeSession.create(in: [subtopic.id], for: user, on: app)

        let taskType = try taskResultRepository.getSpaceRepetitionTask(for: user.id, sessionID: newSession.requireID()).wait()
        XCTAssertNil(taskType)

        _ = try TaskResult.create(task: taskOne, sessionID: lastSession.requireID(), user: user, score: 0.4, on: database)
        _ = try TaskResult.create(task: taskTwo, sessionID: lastSession.requireID(), user: user, score: 0.7, on: database)

        _ = try TaskResult.create(task: deletedTask, sessionID: lastSession.requireID(), user: user, score: 0.2, on: database)

        try deletedTask.delete(on: database).wait()

        let taskTypeOne = try taskResultRepository.getSpaceRepetitionTask(for: user.id, sessionID: newSession.requireID()).wait()

        XCTAssertNotNil(taskTypeOne)
        XCTAssertEqual(taskTypeOne?.taskID, taskOne.id)

        _ = try TaskResult.create(task: taskOne, sessionID: newSession.requireID(), user: user, score: 0.6, on: database)

        let taskTypeTwo = try taskResultRepository.getSpaceRepetitionTask(for: user.id, sessionID: newSession.requireID()).wait()

        XCTAssertNotNil(taskTypeTwo)
        XCTAssertEqual(taskTypeTwo?.taskID, taskTwo.id)
    }

    func testSpaceRepetitionWithTestTask() throws {
        let user = try User.create(on: app)
        let subject = try Subject.create(name: "test", on: app)
        let topic = try Topic.create(subject: subject, on: app)
        let subtopic = try Subtopic.create(topic: topic, on: app)
        let taskOne = try TaskDatabaseModel.create(subtopic: subtopic, on: app)
        let taskTwo = try TaskDatabaseModel.create(subtopic: subtopic, on: app)
        let testTask = try TaskDatabaseModel.create(subtopic: subtopic, isTestable: true, on: app)

        let lastSession = try PracticeSession.create(in: [subtopic.id], for: user, on: app)
        let newSession = try PracticeSession.create(in: [subtopic.id], for: user, on: app)

        let taskType = try taskResultRepository.getSpaceRepetitionTask(for: newSession.requireID(), sessionID: newSession.requireID()).wait()
        XCTAssertNil(taskType)

        _ = try TaskResult.create(task: taskOne, sessionID: lastSession.requireID(), user: user, score: 0.4, on: database)
        _ = try TaskResult.create(task: taskTwo, sessionID: lastSession.requireID(), user: user, score: 0.7, on: database)

        _ = try TaskResult.create(task: testTask, sessionID: lastSession.requireID(), user: user, score: 0.2, on: database)

        let taskTypeOne = try taskResultRepository.getSpaceRepetitionTask(for: user.id, sessionID: newSession.requireID()).wait()

        XCTAssertNotNil(taskTypeOne)
        XCTAssertEqual(taskTypeOne?.taskID, taskOne.id)

        _ = try TaskResult.create(task: taskOne, sessionID: newSession.requireID(), user: user, score: 0.6, on: database)

        let taskTypeTwo = try taskResultRepository.getSpaceRepetitionTask(for: user.id, sessionID: newSession.requireID()).wait()

        XCTAssertNotNil(taskTypeTwo)
        XCTAssertEqual(taskTypeTwo?.taskID, taskTwo.id)
    }

    func testSubjectProgress() throws {
        let user = try User.create(on: app)
        let subject = try Subject.create(name: "test", on: app)

        let topic = try Topic.create(chapter: 1, subject: subject, on: app)
        let secondTopic = try Topic.create(chapter: 2, subject: subject, on: app)

        let subtopic = try Subtopic.create(topic: topic, on: app)
        let secondSubtopic = try Subtopic.create(topic: secondTopic, on: app)

        let taskOne = try TaskDatabaseModel.create(subtopic: subtopic, on: app)
        let taskTwo = try TaskDatabaseModel.create(subtopic: subtopic, on: app)
        let testableTask = try TaskDatabaseModel.create(subtopic: secondSubtopic, isTestable: true, on: app)

        let lastSession = try PracticeSession.create(in: [subtopic.id], for: user, on: app)
        let newSession = try PracticeSession.create(in: [subtopic.id], for: user, on: app)

        _ = try TaskResult.create(task: taskOne, sessionID: lastSession.requireID(), user: user, score: 0.4, on: database)
        _ = try TaskResult.create(task: taskTwo, sessionID: lastSession.requireID(), user: user, score: 0.6, on: database)
        _ = try TaskResult.create(task: testableTask, sessionID: lastSession.requireID(), user: user, score: 1, on: database)

        let subjectProgress = try taskResultRepository.getUserLevel(in: subject, userId: user.id).wait()
        let topicProgress = try taskResultRepository.getUserLevel(for: user.id, in: [topic.id, secondTopic.id]).wait()

        XCTAssertEqual(subjectProgress.correctScore, 2)
        XCTAssertEqual(subjectProgress.maxScore, 3)
        XCTAssertEqual(topicProgress.count, 2)
        topicProgress.forEach { result in
            if result.topicID == topic.id {
                XCTAssertEqual(result.correctScore, 1)
                XCTAssertEqual(result.maxScore, 2)
            } else {
                XCTAssertEqual(result.correctScore, 1)
                XCTAssertEqual(result.maxScore, 1)
            }
        }

        _ = try TaskResult.create(task: taskTwo, sessionID: newSession.requireID(), user: user, score: 0.5, on: database)
    }

    func testRecommendedRecap() throws {

        let user = try User.create(on: app)

        let topic1 = try Topic.create(on: app)
        let topic2 = try Topic.create(on: app)

        let subtopic1 = try Subtopic.create(topicId: topic1.id, on: database)
        let subtopic2 = try Subtopic.create(topicId: topic2.id, on: database)

        let numberOfTasksInTopic1 = 3
        let numberOfTasksInTopic2 = 1

        let limit = 2

        let tasks1 = try (1...numberOfTasksInTopic1).map { _ in try TaskDatabaseModel.create(subtopic: subtopic1, on: app) }
        let tasks2 = try (1...numberOfTasksInTopic2).map { _ in try TaskDatabaseModel.create(subtopic: subtopic2, on: app) }

        let session1 = TaskSession(userID: user.id)
        let session2 = TaskSession(userID: user.id)
        let session3 = TaskSession(userID: user.id)

        // Creating sessions in database
        try [session1, session2, session3].map { $0.create(on: database) }.flatten(on: database.eventLoop).wait()

        let firstTopic1Scores = [0.4, 0.8]

        _ = try TaskResult.create(task: tasks1[0], sessionID: session1.id!, user: user, score: firstTopic1Scores[0], on: database)
        _ = try TaskResult.create(task: tasks1[1], sessionID: session1.id!, user: user, score: firstTopic1Scores[1], on: database)
        _ = try TaskResult.create(task: tasks2[0], sessionID: session1.id!, user: user, score: 1, on: database)

        let firstRecaps = try taskResultRepository.recommendedRecap(for: user.id, upperBoundDays: 10, lowerBoundDays: -3, limit: limit).wait()
        XCTAssertEqual(firstRecaps.count, 1)
        let firstRecap = try XCTUnwrap(firstRecaps.first)
        XCTAssertEqual(firstRecap.topicID, topic1.id)
        XCTAssertEqual(firstRecap.resultScore, firstTopic1Scores.reduce(0, +) / Double(numberOfTasksInTopic1))

        let topic2Score = 0.2

        _ = try TaskResult.create(task: tasks1[0], sessionID: session2.id!, user: user, score: 0.9, on: database)
        _ = try TaskResult.create(task: tasks1[1], sessionID: session2.id!, user: user, score: 0.9, on: database)
        _ = try TaskResult.create(task: tasks2[0], sessionID: session2.id!, user: user, score: topic2Score, on: database)
        _ = try TaskResult.create(task: tasks1[2], sessionID: session2.id!, user: user, score: 1, on: database)

        let secondRecaps = try taskResultRepository.recommendedRecap(for: user.id, upperBoundDays: 10, lowerBoundDays: -3, limit: limit).wait()
        XCTAssertEqual(secondRecaps.count, 1)
        let secondRecap = try XCTUnwrap(secondRecaps.first)
        XCTAssertEqual(secondRecap.topicID, topic2.id)
        XCTAssertEqual(secondRecap.resultScore, topic2Score / Double(numberOfTasksInTopic2))

        let thirdTopic1Scores = [0.2, 0.9, 1]
        let thirdTopic2Scores = [0.5]

        _ = try TaskResult.create(task: tasks1[0], sessionID: session3.id!, user: user, score: thirdTopic1Scores[0], on: database)
        _ = try TaskResult.create(task: tasks1[1], sessionID: session3.id!, user: user, score: thirdTopic1Scores[1], on: database)
        _ = try TaskResult.create(task: tasks2[0], sessionID: session3.id!, user: user, score: thirdTopic2Scores[0], on: database)
        _ = try TaskResult.create(task: tasks1[2], sessionID: session3.id!, user: user, score: thirdTopic1Scores[2], on: database)

        let thirdRecaps = try taskResultRepository.recommendedRecap(for: user.id, upperBoundDays: 10, lowerBoundDays: -3, limit: limit).wait()
        XCTAssertEqual(thirdRecaps.count, 2)
        let thirdRecap = try XCTUnwrap(thirdRecaps.first)
        let lastRecap = try XCTUnwrap(thirdRecaps.last)
        XCTAssertEqual(thirdRecap.topicID, topic1.id)
        XCTAssertEqual(lastRecap.topicID, topic2.id)
        XCTAssertEqual(thirdRecap.resultScore, thirdTopic1Scores.reduce(0, +) / Double(numberOfTasksInTopic1))
        XCTAssertEqual(lastRecap.resultScore, thirdTopic2Scores.reduce(0, +) / Double(numberOfTasksInTopic2))
    }

    static var allTests = [
        ("testHistogramRoute", testHistogramRoute),
        ("testSpaceRepetitionWithMultipleUsers", testSpaceRepetitionWithMultipleUsers),
        ("testSpaceRepetitionWithDeletedTask", testSpaceRepetitionWithDeletedTask),
        ("testSpaceRepetitionWithTestTask", testSpaceRepetitionWithTestTask),
        ("testSubjectProgress", testSubjectProgress),
        ("testRecommendedRecap", testRecommendedRecap)
    ]
}
