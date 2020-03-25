//
//  SubjectTests.swift
//  App
//
//  Created by Mats Mollestad on 11/10/2018.
//

import Vapor
import XCTest
import FluentPostgreSQL
import Crypto
@testable import KognitaCore


class SubjectTests: VaporTestCase {

    func testExportAndImport() throws {
        
        do {
            let subject     = try Subject.create(on: conn)
            let topic       = try Topic.create(subject: subject, on: conn)
            let subtopicOne = try Subtopic.create(topic: topic, on: conn)
            let subtopicTwo = try Subtopic.create(topic: topic, on: conn)

            _ = try MultipleChoiseTask.create(subtopic: subtopicOne, on: conn)
            _ = try MultipleChoiseTask.create(subtopic: subtopicOne, on: conn)
            _ = try FlashCardTask.create(subtopic: subtopicOne, on: conn)

            _ = try MultipleChoiseTask.create(subtopic: subtopicTwo, on: conn)
            _ = try FlashCardTask.create(subtopic: subtopicTwo, on: conn)

            let subjectExport = try Topic.DatabaseRepository
                .exportTopics(in: subject, on: conn).wait()

            XCTAssertEqual(subjectExport.subject.id, subject.id)
            XCTAssertEqual(subjectExport.topics.count, 1)

            guard let topicExport = subjectExport.topics.first else {
                throw Errors.badTest
            }
            XCTAssertEqual(topicExport.topic.id, topic.id)
            XCTAssertEqual(topicExport.subtopics.count, 2)
            XCTAssertEqual(topicExport.subtopics.first?.multipleChoiseTasks.count, 2)
            XCTAssertEqual(topicExport.subtopics.first?.flashCards.count, 1)
            XCTAssertEqual(topicExport.subtopics.last?.multipleChoiseTasks.count, 1)
            XCTAssertEqual(topicExport.subtopics.last?.flashCards.count, 1)

            _ = try Subject.DatabaseRepository.importContent(subjectExport, on: conn).wait()

            XCTAssertEqual(try Task.Repository.all(on: conn).wait().count, 10)
            XCTAssertEqual(try TaskSolution.query(on: conn).all().wait().count, 10)
        } catch {
            XCTFail(error.localizedDescription)
        }
    }

    func testModeratorPrivilege() throws {
        do {
            let user = try User.create(isAdmin: false, on: conn)
            let admin = try User.create(isAdmin: true, on: conn)
            let subject = try Subject.create(on: conn)

            XCTAssertThrowsError(
                try User.DatabaseRepository.isModerator(user: user, subjectID: subject.requireID(), on: conn).wait()
            )
            try Subject.DatabaseRepository.grantModeratorPrivilege(for: user.requireID(), in: subject.requireID(), by: admin, on: conn).wait()
            XCTAssertNoThrow(
                try User.DatabaseRepository.isModerator(user: user, subjectID: subject.requireID(), on: conn).wait()
            )
            // Throw if the user tries to revoke it's own privilege
            XCTAssertThrowsError(
                try Subject.DatabaseRepository.revokeModeratorPrivilege(for: user.requireID(), in: subject.requireID(), by: user, on: conn).wait()
            )
            try Subject.DatabaseRepository.revokeModeratorPrivilege(for: user.requireID(), in: subject.requireID(), by: admin, on: conn).wait()
            XCTAssertThrowsError(
                try User.DatabaseRepository.isModerator(user: user, subjectID: subject.requireID(), on: conn).wait()
            )
        } catch {
            XCTFail(error.localizedDescription)
        }
    }

    func testAllActive() throws {
        do {
            let user = try User.create(on: conn)
            let firstSubject = try Subject.create(on: conn)

            try firstSubject.makeActive(for: user, canPractice: true, on: conn)

            let activeSubjects = try Subject.DatabaseRepository.allActive(for: user, on: conn).wait()
            XCTAssertEqual(activeSubjects.count, 1)
            let activeSubject = try XCTUnwrap(activeSubjects.first)
            try XCTAssertEqual(activeSubject.id, firstSubject.requireID())
        } catch {
            XCTFail(error.localizedDescription)
        }
    }

    func testAllInactive() throws {
        failableTest {

            let user = try User.create(on: conn)
            let subject = try Subject.create(on: conn)

            try subject.makeActive(for: user, canPractice: true, on: conn)
            try subject.makeInactive(for: user, on: conn)

            let activeSubjects = try Subject.DatabaseRepository.allActive(for: user, on: conn).wait()
            XCTAssertEqual(activeSubjects.count, 0)
        }
    }

    func testOverviewContentNotModerator() {
        failableTest {

            let user = try User.create(isAdmin: false, on: conn)
            let topic = try Topic.create(on: conn)
            let subtopic = try Subtopic.create(topic: topic, on: conn)

            let task = try Task.create(subtopic: subtopic, question: "Kognita?", on: conn)
            _ = try FlashCardTask.create(subtopic: subtopic, on: conn)
            _ = try FlashCardTask.create(subtopic: subtopic, on: conn)
            _ = try MultipleChoiseTask.create(subtopic: subtopic, task: task, on: conn)
            _ = try MultipleChoiseTask.create(subtopic: subtopic, isTestable: true, on: conn)
            _ = try MultipleChoiseTask.create(subtopic: subtopic, isTestable: true, on: conn)

            let tasks = try Task.Repository.getTasks(in: topic.subjectId, user: user, query: nil, maxAmount: nil, withSoftDeleted: true, conn: conn).wait()

            XCTAssertFalse(tasks.contains(where: { $0.task.isTestable == true }))
            XCTAssertEqual(tasks.count, 3)

            let filteredTasks = try Task.Repository.getTasks(in: topic.subjectId, user: user, query: .init(taskQuestion: "kog", topics: []), maxAmount: nil, withSoftDeleted: true, conn: conn).wait()
            XCTAssertEqual(filteredTasks.count, 1)
            XCTAssertTrue(tasks.contains(where: { $0.task.question == task.question }))
        }
    }

    func testOverviewContentAsModerator() {
        failableTest {

            let user = try User.create(isAdmin: false, on: conn)
            let admin = try User.create(on: conn)
            let topic = try Topic.create(on: conn)
            let subtopic = try Subtopic.create(topic: topic, on: conn)

            try Subject.DatabaseRepository.grantModeratorPrivilege(for: user.requireID(), in: topic.subjectId, by: admin, on: conn).wait()

            let task = try Task.create(subtopic: subtopic, question: "Kognita?", on: conn)
            _ = try FlashCardTask.create(subtopic: subtopic, on: conn)
            _ = try FlashCardTask.create(subtopic: subtopic, on: conn)
            _ = try MultipleChoiseTask.create(subtopic: subtopic, on: conn)
            _ = try MultipleChoiseTask.create(subtopic: subtopic, task: task, isTestable: true, on: conn)
            _ = try MultipleChoiseTask.create(subtopic: subtopic, isTestable: true, on: conn)

            let tasks = try Task.Repository.getTasks(in: topic.subjectId, user: user, query: nil, maxAmount: nil, withSoftDeleted: true, conn: conn).wait()

            XCTAssertTrue(tasks.contains(where: { $0.task.isTestable == true }))
            XCTAssertEqual(tasks.count, 5)

            let filteredTasks = try Task.Repository.getTasks(in: topic.subjectId, user: user, query: .init(taskQuestion: "kog", topics: []), maxAmount: nil, withSoftDeleted: true, conn: conn).wait()
            XCTAssertEqual(filteredTasks.count, 1)
            XCTAssertTrue(tasks.contains(where: { $0.task.question == task.question }))
            XCTAssertTrue(tasks.contains(where: { $0.task.isTestable == true }))
        }
    }

    func testUnverifedSolutions() {
        failableTest {
            let user = try User.create(isAdmin: false, on: conn)
            let admin = try User.create(on: conn)
            let topic = try Topic.create(on: conn)
            let subtopic = try Subtopic.create(topic: topic, on: conn)

            _ = try FlashCardTask.create(creator: admin, subtopic: subtopic, on: conn) // Verified as the creator is Admin and therefore a moderator
            _ = try FlashCardTask.create(creator: user, subtopic: subtopic, on: conn)
            _ = try MultipleChoiseTask.create(creator: user, subtopic: subtopic, on: conn)
            _ = try MultipleChoiseTask.create(creator: user, subtopic: subtopic, isTestable: true, on: conn)
            _ = try MultipleChoiseTask.create(creator: user, subtopic: subtopic, isTestable: true, on: conn)

            let notModeratorSolutions = try Subject.DatabaseRepository.unverifiedSolutions(in: topic.subjectId, for: user, on: conn).wait()
            let solutions = try Subject.DatabaseRepository.unverifiedSolutions(in: topic.subjectId, for: admin, on: conn).wait()

            XCTAssertEqual(notModeratorSolutions.count, 0)
            XCTAssertEqual(solutions.count, 4)
        }
    }

    func testGetSubjects() {
        failableTest {
            let user = try User.create(on: conn)
            let userTwo = try User.create(on: conn)

            let task = try Task.create(on: conn)
            _ = try Task.create(on: conn)
            _ = try Task.create(on: conn)
            _ = try Task.create(on: conn)

            let subject = try Task.query(on: conn)
                .join(\Subtopic.id, to: \Task.subtopicID)
                .join(\Topic.id, to: \Subtopic.id)
                .join(\Subject.id, to: \Topic.subjectId)
                .filter(\Task.id == task.requireID())
                .decode(Subject.self)
                .first()
                .unwrap(or: Errors.badTest)
                .wait()

            try Subject.DatabaseRepository.mark(active: subject, canPractice: true, for: userTwo, on: conn).wait()

            let subjects = try Subject.DatabaseRepository.allSubjects(for: user, on: conn).wait()
            XCTAssertEqual(subjects.count, 4)
        }
    }

    func testCompendium() {
        failableTest {
            let subject = try Subject.create(on: conn)
            let topic = try Topic.create(subject: subject, on: conn)
            let firstSubtopic = try Subtopic.create(topic: topic, on: conn)
            let secondSubtopic = try Subtopic.create(topic: topic, on: conn)

            _ = try MultipleChoiseTask.create(subtopic: firstSubtopic, on: conn)
            _ = try FlashCardTask.create(subtopic: firstSubtopic, on: conn)
            _ = try FlashCardTask.create(subtopic: secondSubtopic, on: conn)
            _ = try FlashCardTask.create(subtopic: secondSubtopic, on: conn)

            let compendium = try Subject.DatabaseRepository.compendium(for: subject.requireID(), on: conn).wait()
            XCTAssertEqual(compendium.topics.count, 1)
            let compendiumTopic = try XCTUnwrap(compendium.topics.first)
            XCTAssertEqual(compendiumTopic.subtopics.count, 2)
            XCTAssertEqual(compendiumTopic.subtopics.reduce(0) { $0 + $1.questions.count }, 3)
        }
    }

    static let allTests = [
        ("testExportAndImport", testExportAndImport),
        ("testModeratorPrivilege", testModeratorPrivilege),
        ("testAllActive", testAllActive),
        ("testOverviewContentNotModerator", testOverviewContentNotModerator),
        ("testOverviewContentAsModerator", testOverviewContentAsModerator),
        ("testUnverifedSolutions", testUnverifedSolutions),
        ("testGetSubjects", testGetSubjects),
    ]
}
