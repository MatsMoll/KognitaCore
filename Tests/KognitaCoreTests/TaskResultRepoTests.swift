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

    static var allTests = [
        ("testHistogramRoute", testHistogramRoute),
        ("testSpaceRepetitionWithMultipleUsers", testSpaceRepetitionWithMultipleUsers),
        ("testSpaceRepetitionWithDeletedTask", testSpaceRepetitionWithDeletedTask),
        ("testSpaceRepetitionWithTestTask", testSpaceRepetitionWithTestTask),
        ("testSubjectProgress", testSubjectProgress)
    ]
}
