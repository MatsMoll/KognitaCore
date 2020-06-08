//
//  TaskResultRepoTests.swift
//  KognitaCoreTests
//
//  Created by Mats Mollestad on 30/04/2019.
//

import Vapor
import XCTest
import FluentPostgreSQL
@testable import KognitaCore
import KognitaCoreTestable

class TaskResultRepoTests: VaporTestCase {

    func testHistogramRoute() throws {

        let user = try User.create(on: conn)
        let subject = try Subject.create(name: "test", on: conn)
        let topic = try Topic.create(subject: subject, on: conn)
        let subtopic = try Subtopic.create(topic: topic, on: conn)
        let taskOne = try Task.create(subtopic: subtopic, on: conn)
        let taskTwo = try Task.create(subtopic: subtopic, on: conn)

        let sessionOne = try PracticeSession.create(in: [subtopic.id], for: user, on: conn)
        let sessionTwo = try PracticeSession.create(in: [subtopic.id], for: user, on: conn)

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
        let user = try User.create(on: conn)
        let secondUser = try User.create(on: conn)
        let subject = try Subject.create(name: "test", on: conn)
        let topic = try Topic.create(subject: subject, on: conn)
        let subtopic = try Subtopic.create(topic: topic, on: conn)
        let otherSubtopic = try Subtopic.create(topic: topic, on: conn)
        let taskOne = try Task.create(subtopic: subtopic, on: conn)
        let taskTwo = try Task.create(subtopic: subtopic, on: conn)
        let otherTask = try Task.create(subtopic: otherSubtopic, on: conn)

        let otherSession = try PracticeSession.create(in: [subtopic.id], for: secondUser, on: conn)
        let lastSession = try PracticeSession.create(in: [subtopic.id], for: user, on: conn)
        let newSession = try PracticeSession.create(in: [subtopic.id], for: user, on: conn)

        let taskType = try TaskResult.DatabaseRepository.getSpaceRepetitionTask(for: newSession, on: conn).wait()
        XCTAssertNil(taskType)

        _ = try TaskResult.create(task: taskOne, sessionID: lastSession.requireID(), user: user, score: 0.4, on: conn)
        _ = try TaskResult.create(task: taskTwo, sessionID: lastSession.requireID(), user: user, score: 0.7, on: conn)

        _ = try TaskResult.create(task: taskTwo, sessionID: otherSession.requireID(), user: secondUser, score: 0.2, on: conn)

        let taskTypeOne = try TaskResult.DatabaseRepository.getSpaceRepetitionTask(for: newSession, on: conn).wait()

        XCTAssertNotNil(taskTypeOne)
        XCTAssertEqual(taskTypeOne?.taskID, taskOne.id)

        _ = try TaskResult.create(task: taskOne, sessionID: newSession.requireID(), user: user, score: 0.6, on: conn)
        _ = try TaskResult.create(task: otherTask, sessionID: lastSession.requireID(), user: user, score: 0.2, on: conn)

        let taskTypeTwo = try TaskResult.DatabaseRepository.getSpaceRepetitionTask(for: newSession, on: conn).wait()

        XCTAssertNotNil(taskTypeTwo)
        XCTAssertEqual(taskTypeTwo?.taskID, taskTwo.id)
    }

    func testSpaceRepetitionWithDeletedTask() throws {
        let user = try User.create(on: conn)
        let subject = try Subject.create(name: "test", on: conn)
        let topic = try Topic.create(subject: subject, on: conn)
        let subtopic = try Subtopic.create(topic: topic, on: conn)
        let taskOne = try Task.create(subtopic: subtopic, on: conn)
        let taskTwo = try Task.create(subtopic: subtopic, on: conn)
        let deletedTask = try Task.create(subtopic: subtopic, on: conn)

        let lastSession = try PracticeSession.create(in: [subtopic.id], for: user, on: conn)
        let newSession = try PracticeSession.create(in: [subtopic.id], for: user, on: conn)

        let taskType = try TaskResult.DatabaseRepository.getSpaceRepetitionTask(for: newSession, on: conn).wait()
        XCTAssertNil(taskType)

        _ = try TaskResult.create(task: taskOne, sessionID: lastSession.requireID(), user: user, score: 0.4, on: conn)
        _ = try TaskResult.create(task: taskTwo, sessionID: lastSession.requireID(), user: user, score: 0.7, on: conn)

        _ = try TaskResult.create(task: deletedTask, sessionID: lastSession.requireID(), user: user, score: 0.2, on: conn)

        try deletedTask.delete(on: conn).wait()

        let taskTypeOne = try TaskResult.DatabaseRepository.getSpaceRepetitionTask(for: newSession, on: conn).wait()

        XCTAssertNotNil(taskTypeOne)
        XCTAssertEqual(taskTypeOne?.taskID, taskOne.id)

        _ = try TaskResult.create(task: taskOne, sessionID: newSession.requireID(), user: user, score: 0.6, on: conn)

        let taskTypeTwo = try TaskResult.DatabaseRepository.getSpaceRepetitionTask(for: newSession, on: conn).wait()

        XCTAssertNotNil(taskTypeTwo)
        XCTAssertEqual(taskTypeTwo?.taskID, taskTwo.id)
    }

    func testSpaceRepetitionWithTestTask() throws {
        let user = try User.create(on: conn)
        let subject = try Subject.create(name: "test", on: conn)
        let topic = try Topic.create(subject: subject, on: conn)
        let subtopic = try Subtopic.create(topic: topic, on: conn)
        let taskOne = try Task.create(subtopic: subtopic, on: conn)
        let taskTwo = try Task.create(subtopic: subtopic, on: conn)
        let testTask = try Task.create(subtopic: subtopic, isTestable: true, on: conn)

        let lastSession = try PracticeSession.create(in: [subtopic.id], for: user, on: conn)
        let newSession = try PracticeSession.create(in: [subtopic.id], for: user, on: conn)

        let taskType = try TaskResult.DatabaseRepository.getSpaceRepetitionTask(for: newSession, on: conn).wait()
        XCTAssertNil(taskType)

        _ = try TaskResult.create(task: taskOne, sessionID: lastSession.requireID(), user: user, score: 0.4, on: conn)
        _ = try TaskResult.create(task: taskTwo, sessionID: lastSession.requireID(), user: user, score: 0.7, on: conn)

        _ = try TaskResult.create(task: testTask, sessionID: lastSession.requireID(), user: user, score: 0.2, on: conn)

        let taskTypeOne = try TaskResult.DatabaseRepository.getSpaceRepetitionTask(for: newSession, on: conn).wait()

        XCTAssertNotNil(taskTypeOne)
        XCTAssertEqual(taskTypeOne?.taskID, taskOne.id)

        _ = try TaskResult.create(task: taskOne, sessionID: newSession.requireID(), user: user, score: 0.6, on: conn)

        let taskTypeTwo = try TaskResult.DatabaseRepository.getSpaceRepetitionTask(for: newSession, on: conn).wait()

        XCTAssertNotNil(taskTypeTwo)
        XCTAssertEqual(taskTypeTwo?.taskID, taskTwo.id)
    }

    func testSubjectProgress() throws {
        do {
            let user = try User.create(on: conn)
            let subject = try Subject.create(name: "test", on: conn)

            let topic = try Topic.create(chapter: 1, subject: subject, on: conn)
            let secondTopic = try Topic.create(chapter: 2, subject: subject, on: conn)

            let subtopic = try Subtopic.create(topic: topic, on: conn)
            let secondSubtopic = try Subtopic.create(topic: secondTopic, on: conn)

            let taskOne = try Task.create(subtopic: subtopic, on: conn)
            let taskTwo = try Task.create(subtopic: subtopic, on: conn)
            let testableTask = try Task.create(subtopic: secondSubtopic, isTestable: true, on: conn)

            let lastSession = try PracticeSession.create(in: [subtopic.id], for: user, on: conn)
            let newSession = try PracticeSession.create(in: [subtopic.id], for: user, on: conn)

            _ = try TaskResult.create(task: taskOne, sessionID: lastSession.requireID(), user: user, score: 0.4, on: conn)
            _ = try TaskResult.create(task: taskTwo, sessionID: lastSession.requireID(), user: user, score: 0.6, on: conn)
            _ = try TaskResult.create(task: testableTask, sessionID: lastSession.requireID(), user: user, score: 1, on: conn)

            let subjectProgress = try TaskResult.DatabaseRepository.getUserLevel(in: subject, userId: user.id, on: conn).wait()
            let topicProgress = try TaskResult.DatabaseRepository.getUserLevel(for: user.id, in: [topic.id, secondTopic.id], on: conn).wait()

            XCTAssertEqual(subjectProgress.correctScore, 2)
            XCTAssertEqual(subjectProgress.maxScore, 3)
            XCTAssertEqual(topicProgress.count, 2)
            try topicProgress.forEach { result in
                if try result.topicID == topic.id {
                    XCTAssertEqual(result.correctScore, 1)
                    XCTAssertEqual(result.maxScore, 2)
                } else {
                    XCTAssertEqual(result.correctScore, 1)
                    XCTAssertEqual(result.maxScore, 1)
                }
            }

            _ = try TaskResult.create(task: taskTwo, sessionID: newSession.requireID(), user: user, score: 0.5, on: conn)
        } catch {
            XCTFail(error.localizedDescription)
        }
    }

    static var allTests = [
        ("testHistogramRoute", testHistogramRoute),
        ("testSpaceRepetitionWithMultipleUsers", testSpaceRepetitionWithMultipleUsers),
        ("testSpaceRepetitionWithDeletedTask", testSpaceRepetitionWithDeletedTask),
        ("testSpaceRepetitionWithTestTask", testSpaceRepetitionWithTestTask),
        ("testSubjectProgress", testSubjectProgress)
    ]
}
