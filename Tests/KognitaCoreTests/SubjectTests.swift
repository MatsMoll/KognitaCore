//
//  SubjectTests.swift
//  App
//
//  Created by Mats Mollestad on 11/10/2018.
//

import Vapor
import XCTest
@testable import KognitaCore
import KognitaCoreTestable

class SubjectTests: VaporTestCase {

    lazy var taskResultRepository: TaskResultRepositoring = { TestableRepositories.testable(with: app).taskResultRepository }()
    lazy var topicRepository: TopicRepository = { TestableRepositories.testable(with: app).topicRepository }()
    lazy var subjectRepository: SubjectRepositoring = { TestableRepositories.testable(with: app).subjectRepository }()
    lazy var taskSolutionRepository: TaskSolutionRepositoring = { TestableRepositories.testable(with: app).taskSolutionRepository }()
    lazy var taskRepository: TaskDatabaseModel.DatabaseRepository = { TaskDatabaseModel.DatabaseRepository(database: app.db, repositories: TestableRepositories.testable(with: app)) }()
    lazy var userRepository: UserRepository = { TestableRepositories.testable(with: app).userRepository }()

    func testExportAndImport() throws {
        let subject     = try Subject.create(on: app)
        let topic       = try Topic.create(subject: subject, on: app)
        let subtopicOne = try Subtopic.create(topic: topic, on: app)
        let subtopicTwo = try Subtopic.create(topic: topic, on: app)

        _ = try MultipleChoiceTask.create(subtopic: subtopicOne, on: app)
        _ = try MultipleChoiceTask.create(subtopic: subtopicOne, on: app)
        _ = try FlashCardTask.create(subtopic: subtopicOne, on: app)

        _ = try MultipleChoiceTask.create(subtopic: subtopicTwo, on: app)
        _ = try FlashCardTask.create(subtopic: subtopicTwo, on: app)

        let subjectExport = try topicRepository
            .exportTopics(in: subject).wait()

        XCTAssertEqual(subjectExport.subject.id, subject.id)
        XCTAssertEqual(subjectExport.topics.count, 1)

        guard let topicExport = subjectExport.topics.first else {
            throw Errors.badTest
        }
        XCTAssertEqual(topicExport.topic.id, topic.id)
        XCTAssertEqual(topicExport.subtopics.count, 2)
        XCTAssertEqual(topicExport.subtopics.first?.multipleChoiceTasks.count, 2)
        XCTAssertEqual(topicExport.subtopics.first?.typingTasks.count, 1)
        XCTAssertEqual(topicExport.subtopics.last?.multipleChoiceTasks.count, 1)
        XCTAssertEqual(topicExport.subtopics.last?.typingTasks.count, 1)

        let modifiedImportContent = Subject.Import(
            subject: Subject.Create.Data(
                code: Subject.uniqueCode(),
                name: subjectExport.subject.name,
                description: subjectExport.subject.description,
                category: subjectExport.subject.category
            ),
            topics: subjectExport.importContent.topics,
            resources: []
        )
        _ = try subjectRepository.importContent(modifiedImportContent).wait()

        XCTAssertEqual(try taskRepository.all().wait().count, 10)
        XCTAssertEqual(try TaskSolution.DatabaseModel.query(on: database).all().wait().count, 10)
    }

    func testExportAndInvalidImport() throws {
        let subject     = try Subject.create(on: app)
        let topic       = try Topic.create(subject: subject, on: app)
        let subtopicOne = try Subtopic.create(topic: topic, on: app)
        let subtopicTwo = try Subtopic.create(topic: topic, on: app)

        _ = try MultipleChoiceTask.create(subtopic: subtopicOne, on: app)
        _ = try MultipleChoiceTask.create(subtopic: subtopicOne, on: app)
        _ = try FlashCardTask.create(subtopic: subtopicOne, on: app)

        _ = try MultipleChoiceTask.create(subtopic: subtopicTwo, on: app)
        _ = try FlashCardTask.create(subtopic: subtopicTwo, on: app)

        let subjectExport = try topicRepository
            .exportTopics(in: subject).wait()
        let subjectImport = subjectExport.importContent
        let modefiedImport = Subject.Import(
            subject: Subject.Create.Data(
                code: Subject.uniqueCode(),
                name: subjectImport.subject.name,
                description: subjectImport.subject.description,
                category: subjectImport.subject.category
            ),
            topics: subjectImport.topics + [
                Topic.Import(
                    topic: .init(
                        subjectID: 0,
                        name: "Import",
                        chapter: 10
                    ),
                    subtopics: [
                        Subtopic.Import(
                            subtopic: .init(name: "Test", topicId: 0),
                            multipleChoiceTasks: [
                                MultipleChoiceTask.Import(
                                    description: nil,
                                    question: "Test",
                                    exam: nil,
                                    isTestable: false,
                                    isMultipleSelect: false,
                                    // Should cause an error
                                    choices: [],
                                    solutions: [],
                                    sources: []
                                )
                            ],
                            typingTasks: []
                        )
                    ]
                )
            ],
            resources: []
        )
        let modifiedImportContent = Subject.Import(
            subject: Subject.Create.Data(
                code: Subject.uniqueCode(),
                name: subjectImport.subject.name,
                description: subjectImport.subject.description,
                category: subjectImport.subject.category
            ),
            topics: subjectImport.topics,
            resources: []
        )

        do {
            _ = try app.repositoriesFactory.make!.repositories(app: app) { (repo) in
                repo.subjectRepository.importContent(modefiedImport)
            }
            .wait()
        } catch let error as Abort {
            XCTAssertEqual(error.status, .badRequest)
        } catch {
            XCTFail(error.localizedDescription)
        }

        XCTAssertEqual(try taskRepository.all().wait().count, 5)
        XCTAssertEqual(try TaskSolution.DatabaseModel.query(on: database).all().wait().count, 5)

        _ = try app.repositoriesFactory.make!.repositories(app: app) { (repo) in
            repo.subjectRepository.importContent(modifiedImportContent)
        }
        .wait()

        XCTAssertEqual(try taskRepository.all().wait().count, 10)
        XCTAssertEqual(try TaskSolution.DatabaseModel.query(on: database).all().wait().count, 10)
    }

    func testModeratorPrivilege() throws {
        let user = try User.create(isAdmin: false, on: app)
        let admin = try User.create(isAdmin: true, on: app)
        let subject = try Subject.create(on: app)

        XCTAssertEqual(try userRepository.isModerator(user: user, subjectID: subject.id).wait(), false)
        try subjectRepository.grantModeratorPrivilege(for: user.id, in: subject.id, by: admin).wait()
        XCTAssertEqual(try userRepository.isModerator(user: user, subjectID: subject.id).wait(), true)
        // Throw if the user tries to revoke it's own privilege
        XCTAssertThrowsError(
            try subjectRepository.revokeModeratorPrivilege(for: user.id, in: subject.id, by: user).wait()
        )
        try subjectRepository.revokeModeratorPrivilege(for: user.id, in: subject.id, by: admin).wait()
        XCTAssertEqual(try userRepository.isModerator(user: user, subjectID: subject.id).wait(), false)
    }

    func testAllActive() throws {
        do {
            let user = try User.create(on: app)
            let firstSubject = try Subject.create(on: app)

            try firstSubject.makeActive(for: user, canPractice: true, on: app)

            let activeSubjects = try subjectRepository.allActive(for: user.id).wait()
            XCTAssertEqual(activeSubjects.count, 1)
            let activeSubject = try XCTUnwrap(activeSubjects.first)
            XCTAssertEqual(activeSubject.id, firstSubject.id)
        } catch {
            XCTFail(error.localizedDescription)
        }
    }

    func testAllInactive() throws {
        failableTest {

            let user = try User.create(on: app)
            let subject = try Subject.create(on: app)

            try subject.makeActive(for: user, canPractice: true, on: app)
            try subject.makeInactive(for: user, on: app)

            let activeSubjects = try subjectRepository.allActive(for: user.id).wait()
            XCTAssertEqual(activeSubjects.count, 0)
        }
    }

    func testOverviewContentNotModerator() throws {

        let user = try User.create(isAdmin: false, on: app)
        let topic = try Topic.create(on: app)
        let subtopic = try Subtopic.create(topic: topic, on: app)

        let task = try TaskDatabaseModel.create(subtopic: subtopic, question: "Kognita?", on: app)
        _ = try FlashCardTask.create(subtopic: subtopic, on: app)
        _ = try FlashCardTask.create(subtopic: subtopic, on: app)
        _ = try MultipleChoiceTask.create(subtopic: subtopic, task: task, on: app)
        _ = try MultipleChoiceTask.create(subtopic: subtopic, isTestable: true, on: app)
        _ = try MultipleChoiceTask.create(subtopic: subtopic, isTestable: true, on: app)

        let tasks = try taskRepository.getTasks(in: topic.subjectID, user: user, query: nil, maxAmount: nil, withSoftDeleted: true).wait()

//            XCTAssertFalse(tasks.contains(where: { $0..isTestable == true }))
        XCTAssertEqual(tasks.count, 3)

        let filteredTasks = try taskRepository.getTasks(in: topic.subjectID, user: user, query: .init(taskQuestion: "kog", topics: []), maxAmount: nil, withSoftDeleted: true).wait()
        XCTAssertEqual(filteredTasks.count, 1)
//            XCTAssertTrue(tasks.contains(where: { $0.task.question == task.question }))
    }

    func testOverviewContentAsModerator() throws {

        let user = try User.create(isAdmin: false, on: app)
        let admin = try User.create(on: app)
        let topic = try Topic.create(on: app)
        let subtopic = try Subtopic.create(topic: topic, on: app)

        try subjectRepository.grantModeratorPrivilege(for: user.id, in: topic.subjectID, by: admin).wait()

        let task = try TaskDatabaseModel.create(subtopic: subtopic, question: "Kognita?", on: app)
        _ = try FlashCardTask.create(subtopic: subtopic, on: app)
        _ = try FlashCardTask.create(subtopic: subtopic, on: app)
        _ = try MultipleChoiceTask.create(subtopic: subtopic, on: app)
        _ = try MultipleChoiceTask.create(subtopic: subtopic, task: task, isTestable: true, on: app)
        _ = try MultipleChoiceTask.create(subtopic: subtopic, isTestable: true, on: app)

        let tasks = try taskRepository.getTasks(in: topic.subjectID, user: user, query: nil, maxAmount: nil, withSoftDeleted: true).wait()

//            XCTAssertTrue(tasks.contains(where: { $0.task.isTestable == true }))
        XCTAssertEqual(tasks.count, 5)

        let filteredTasks = try taskRepository.getTasks(in: topic.subjectID, user: user, query: .init(taskQuestion: "kog", topics: []), maxAmount: nil, withSoftDeleted: true).wait()
        XCTAssertEqual(filteredTasks.count, 1)
//            XCTAssertTrue(tasks.contains(where: { $0.task.question == task.question }))
//            XCTAssertTrue(tasks.contains(where: { $0.task.isTestable == true }))
    }

    func testUnverifedSolutions() throws {
        let user = try User.create(isAdmin: false, on: app)
        let admin = try User.create(on: app)
        let topic = try Topic.create(on: app)
        let subtopic = try Subtopic.create(topic: topic, on: app)

        _ = try FlashCardTask.create(creator: admin, subtopic: subtopic, on: app) // Verified as the creator is Admin and therefore a moderator
        _ = try FlashCardTask.create(creator: user, subtopic: subtopic, on: app)
        _ = try MultipleChoiceTask.create(creator: user, subtopic: subtopic, on: app)
        _ = try MultipleChoiceTask.create(creator: user, subtopic: subtopic, isTestable: true, on: app)
        _ = try MultipleChoiceTask.create(creator: user, subtopic: subtopic, isTestable: true, on: app)

        let notModeratorSolutions = try taskSolutionRepository.unverifiedSolutions(in: topic.subjectID, for: user).wait()
        let solutions = try taskSolutionRepository.unverifiedSolutions(in: topic.subjectID, for: admin).wait()

        XCTAssertEqual(notModeratorSolutions.count, 0)
        XCTAssertEqual(solutions.count, 4)
    }

    func testGetSubjects() {
        failableTest {
            let user = try User.create(on: app)
            let userTwo = try User.create(on: app)

            let task = try TaskDatabaseModel.create(on: app)
            _ = try TaskDatabaseModel.create(on: app)
            _ = try TaskDatabaseModel.create(on: app)
            _ = try TaskDatabaseModel.create(on: app)

            let subject = try TaskDatabaseModel.query(on: database)
                .join(parent: \TaskDatabaseModel.$subtopic)
                .join(parent: \Subtopic.DatabaseModel.$topic)
                .join(parent: \Topic.DatabaseModel.$subject)
                .filter(\TaskDatabaseModel.$id == task.requireID())
                .first(Subject.DatabaseModel.self)
                .unwrap(or: Errors.badTest)
                .wait()

            try subjectRepository.mark(active: subject.requireID(), canPractice: true, for: userTwo.id).wait()

            let subjects = try subjectRepository.allSubjects(for: user.id, searchQuery: nil).wait()
            XCTAssertEqual(subjects.count, 4)
        }
    }

    func testCompendium() {
        failableTest {
            let user = try User.create(on: app)
            let subject = try Subject.create(on: app)
            let topic = try Topic.create(subject: subject, on: app)
            let firstSubtopic = try Subtopic.create(topic: topic, on: app)
            let secondSubtopic = try Subtopic.create(topic: topic, on: app)

            _ = try MultipleChoiceTask.create(subtopic: firstSubtopic, on: app)
            _ = try FlashCardTask.create(subtopic: firstSubtopic, on: app)
            _ = try FlashCardTask.create(subtopic: secondSubtopic, on: app)
            _ = try FlashCardTask.create(subtopic: secondSubtopic, on: app)

            let compendium = try subjectRepository.compendium(for: subject.id, filter: SubjectCompendiumFilter(subtopicIDs: nil), for: user.id).wait()
            let noContent = try subjectRepository.compendium(for: subject.id, filter: SubjectCompendiumFilter(subtopicIDs: [3]), for: user.id).wait()
            let filteredContent = try subjectRepository.compendium(for: subject.id, filter: SubjectCompendiumFilter(subtopicIDs: [firstSubtopic.id]), for: user.id).wait()

            XCTAssertEqual(compendium.topics.count, 1)
            XCTAssertEqual(noContent.topics.count, 0)
            XCTAssertEqual(filteredContent.topics.count, 1)
            let compendiumTopic = try XCTUnwrap(compendium.topics.first)
            let filteredTopic = try XCTUnwrap(filteredContent.topics.first)
            XCTAssertEqual(compendiumTopic.subtopics.count, 2)
            XCTAssertEqual(filteredTopic.subtopics.count, 1)
            XCTAssertEqual(compendiumTopic.subtopics.reduce(0) { $0 + $1.questions.count }, 3)
            XCTAssertEqual(filteredTopic.subtopics.reduce(0) { $0 + $1.questions.count }, 1)
        }
    }

    func testSubjectForPracticeSession() {
        failableTest {
            let user = try User.create(on: app)

            let taskOne = try TaskDatabaseModel.create(on: app)
            let taskTwo = try TaskDatabaseModel.create(on: app)

            let subjectIDOne = try subjectRepository.subjectIDFor(subtopicIDs: [taskOne.$subtopic.id]).wait()
            let subjectOne = try Subject.DatabaseModel.find(subjectIDOne, on: database).unwrap(or: Errors.badTest).wait()

            let subjectIDTwo = try subjectRepository.subjectIDFor(subtopicIDs: [taskTwo.$subtopic.id]).wait()
            let subjectTwo = try Subject.DatabaseModel.find(subjectIDTwo, on: database).unwrap(or: Errors.badTest).wait()

            XCTAssertNotEqual(subjectTwo.id, subjectOne.id)

            let sessionOne = try PracticeSession.create(in: [taskOne.$subtopic.id], for: user, on: app)
            let sessionTwo = try PracticeSession.create(in: [taskTwo.$subtopic.id], for: user, on: app)

            let sessionSubjectOne = try subjectRepository.subject(for: sessionOne).wait()
            let sessionSubjectTwo = try subjectRepository.subject(for: sessionTwo).wait()

            XCTAssertEqual(subjectOne.id, sessionSubjectOne.id)
            XCTAssertEqual(subjectTwo.id, sessionSubjectTwo.id)
        }
    }

    func testImportTopicToSubjectWithExamQuestions() throws {

        _ = try User.create(on: app)

        let numberOfTopics = 2
        let expectedNumberOfTasks = numberOfTopics * 7
        let expectedNumberOfExamTasks = numberOfTopics * 5

        let importContent = Subject.Import(
            subject: .init(code: "TDT123", name: "Test", description: "Test", category: "Test"),
            topics: (1...numberOfTopics).map {
                Topic.Import.testData(chapter: $0, topicName: "Test \($0)")
            },
            resources: []
        )

        _ = try app.repositoriesFactory.make!.repositories(app: app) { (repo) in
            repo.subjectRepository.importContent(importContent)
        }
        .wait()

        let allTasks = try TaskDatabaseModel.query(on: database).all().wait()
        XCTAssertEqual(allTasks.count, expectedNumberOfTasks)
        let numberOfExamTasks = allTasks.filter { $0.$exam.id != nil }
        XCTAssertEqual(numberOfExamTasks.count, expectedNumberOfExamTasks)
    }

    static let allTests = [
        ("testExportAndImport", testExportAndImport),
        ("testModeratorPrivilege", testModeratorPrivilege),
        ("testAllActive", testAllActive),
        ("testOverviewContentNotModerator", testOverviewContentNotModerator),
        ("testOverviewContentAsModerator", testOverviewContentAsModerator),
        ("testUnverifedSolutions", testUnverifedSolutions),
        ("testGetSubjects", testGetSubjects),
        ("testSubjectForPracticeSession", testSubjectForPracticeSession)
    ]
}
