//
//  WorkPointTests.swift
//  KognitaCoreTests
//
//  Created by Mats Mollestad on 25/09/2019.
//

import Vapor
import XCTest
import FluentPostgreSQL
@testable import KognitaCore
import KognitaCoreTestable

//class WorkPointTests: VaporTestCase {

//    func testLeaderboard() throws {
//
//        let user = try User.create(on: conn)
//        let userTwo = try User.create(on: conn)
//        let userThree = try User.create(on: conn)
//
//        let subtopic = try Subtopic.create(on: conn)
//
//        _ = try MultipleChoiseTask.create(subtopic: subtopic, on: conn)
//        _ = try MultipleChoiseTask.create(subtopic: subtopic, on: conn)
//        _ = try MultipleChoiseTask.create(on: conn)
//
//        let create = try PracticeSession.Create.Data(
//            numberOfTaskGoal: 2,
//            subtopicsIDs: [
//                subtopic.requireID()
//            ],
//            topicIDs: []
//        )
//
//        let firstSession = try PracticeSession.Repository
//            .create(from: create, by: user, on: conn).wait()
//        let secondSession = try PracticeSession.Repository
//            .create(from: create, by: user, on: conn).wait()
//
//        let sessionUserTwo = try PracticeSession.Repository
//            .create(from: create, by: userTwo, on: conn).wait()
//        let sessionUserThree = try PracticeSession.Repository
//            .create(from: create, by: userThree, on: conn).wait()
//
//        var submit = MultipleChoiseTask.Submit(
//            timeUsed: 20,
//            choises: [],
//            taskIndex: 1
//        )
//        _ = try PracticeSession.Repository
//            .submitMultipleChoise(submit, in: firstSession, by: user, on: conn).wait()
//        submit.taskIndex = 2
//        _ = try PracticeSession.Repository
//            .submitMultipleChoise(submit, in: firstSession, by: user, on: conn).wait()
//
//        submit.taskIndex = 1
//        _ = try PracticeSession.Repository
//            .submitMultipleChoise(submit, in: sessionUserTwo, by: userTwo, on: conn).wait()
//        submit.taskIndex = 2
//        _ = try PracticeSession.Repository
//            .submitMultipleChoise(submit, in: sessionUserTwo, by: userTwo, on: conn).wait()
//
//        submit.taskIndex = 1
//        _ = try PracticeSession.Repository
//            .submitMultipleChoise(submit, in: sessionUserThree, by: userThree, on: conn).wait()
//
//        submit.taskIndex = 1
//        _ = try PracticeSession.Repository
//            .submitMultipleChoise(submit, in: secondSession, by: user, on: conn).wait()
//        submit.taskIndex = 2
//        _ = try PracticeSession.Repository
//            .submitMultipleChoise(submit, in: secondSession, by: user, on: conn).wait()
//
//        let leaderboardFirst = try WorkPoints.Repository.leaderboard(for: user, amount: 2, on: conn).wait()
//        let leaderboardSecond = try WorkPoints.Repository.leaderboard(for: userTwo, amount: 3, on: conn).wait()
//        let leaderboardThree = try WorkPoints.Repository.leaderboard(for: userThree, amount: 2, on: conn).wait()
//
//        XCTAssertEqual(leaderboardFirst.count, 2)
//
//        guard leaderboardFirst.count >= 2 else { return }
//
//        XCTAssertEqual(leaderboardFirst.first?.userID, user.id)
//        XCTAssertEqual(leaderboardFirst.last?.userID, userTwo.id)
//
//        XCTAssertEqual(leaderboardSecond.first?.userID, user.id)
//        XCTAssertEqual(leaderboardSecond[1].userID, userTwo.id)
//        XCTAssertEqual(leaderboardSecond.last?.userID, userThree.id)
//
//        XCTAssertEqual(leaderboardThree.first?.userID, userTwo.id)
//        XCTAssertEqual(leaderboardThree.last?.userID, userThree.id)
//    }
//
//    func testSubjectLeaderboard() throws {
//
//        let user = try User.create(on: conn)
//
//        let subject = try Subject.create(on: conn)
//        let topic = try Topic.create(subject: subject, on: conn)
//
//        let subtopic = try Subtopic.create(topic: topic, on: conn)
//        let subtopicTwo = try Subtopic.create(on: conn)
//
//        _ = try MultipleChoiseTask.create(subtopic: subtopic, on: conn)
//        _ = try MultipleChoiseTask.create(subtopic: subtopic, on: conn)
//        _ = try MultipleChoiseTask.create(subtopic: subtopicTwo, on: conn)
//
//        let create = try PracticeSession.Create.Data(
//            numberOfTaskGoal: 2,
//            subtopicsIDs: [
//                subtopic.requireID()
//            ],
//            topicIDs: []
//        )
//        let createTwo = try PracticeSession.Create.Data(
//            numberOfTaskGoal: 2,
//            subtopicsIDs: [
//                subtopicTwo.requireID()
//            ],
//            topicIDs: []
//        )
//
//        let firstSession = try PracticeSession.Repository
//            .create(from: create, by: user, on: conn).wait()
//        let secondSession = try PracticeSession.Repository
//            .create(from: createTwo, by: user, on: conn).wait()
//
//        var submit = MultipleChoiseTask.Submit(
//            timeUsed: 20,
//            choises: [],
//            taskIndex: 1
//        )
//        _ = try PracticeSession.Repository
//            .submitMultipleChoise(submit, in: firstSession, by: user, on: conn).wait()
//        submit.taskIndex = 2
//        _ = try PracticeSession.Repository
//            .submitMultipleChoise(submit, in: firstSession, by: user, on: conn).wait()
//
//        submit.taskIndex = 1
//        _ = try PracticeSession.Repository
//            .submitMultipleChoise(submit, in: secondSession, by: user, on: conn).wait()
//
//        let leaderboardOverall = try WorkPoints.Repository.leaderboard(for: user, on: conn).wait()
//        let leaderboardSubject = try WorkPoints.Repository.leaderboard(in: subject, for: user, on: conn).wait()
//        let leaderboardTopic = try WorkPoints.Repository.leaderboard(in: topic, for: user, on: conn).wait()
//
//        XCTAssertEqual(leaderboardOverall.count, 1)
//        XCTAssertEqual(leaderboardSubject.count, 1)
//
//        XCTAssertEqual(leaderboardOverall.first?.userID, user.id)
//
//        XCTAssertEqual(leaderboardOverall.first?.userName, user.name)
//        XCTAssertEqual(leaderboardSubject.first?.userName, user.name)
//        XCTAssertEqual(leaderboardTopic.first?.userName, user.name)
//
//        XCTAssertEqual(leaderboardOverall.first?.userID, leaderboardSubject.first?.userID)
//        XCTAssertEqual(leaderboardOverall.first?.userID, leaderboardTopic.first?.userID)
//        XCTAssertEqual(leaderboardTopic.first?.pointsSum, leaderboardSubject.first?.pointsSum) // In this case
//        XCTAssertNotEqual(leaderboardOverall.first?.pointsSum, leaderboardSubject.first?.pointsSum)
//        XCTAssertNotEqual(leaderboardSubject.first?.pointsSum, 0)
//        XCTAssertNotEqual(leaderboardOverall.first?.pointsSum, 0)
//    }
//
//    static var allTests = [
//        ("testLeaderboard", testLeaderboard),
//        ("testSubjectLeaderboard", testSubjectLeaderboard)
//    ]
//}
