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

    lazy var topicRepository: TopicRepository = { TestableRepositories.testable(with: app).topicRepository }()
    lazy var subtopicRepository: SubtopicRepositoring = { TestableRepositories.testable(with: app).subtopicRepository }()

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

    func testImportTopicToSubjectWithExamQuestions() throws {

        let subject     = try Subject.create(on: app)
        let topic       = try Topic.create(subject: subject, on: app)
        let subtopicOne = try Subtopic.create(topic: topic, on: app)
        let subtopicTwo = try Subtopic.create(topic: topic, on: app)

        _ = try MultipleChoiceTask.create(subtopic: subtopicOne, on: app)
        _ = try MultipleChoiceTask.create(subtopic: subtopicOne, on: app)
        _ = try FlashCardTask.create(subtopic: subtopicOne, on: app)

        _ = try MultipleChoiceTask.create(subtopic: subtopicTwo, on: app)
        _ = try FlashCardTask.create(subtopic: subtopicTwo, on: app)

        let importContent = Topic.Import.testData(chapter: 2, topicName: "Test")

        _ = try app.repositoriesFactory.make!.repositories(app: app) { (repo) in
            repo.topicRepository.importContent(from: importContent, in: subject.id)
        }
        .wait()

        let allTasks = try TaskDatabaseModel.query(on: database).all().wait()
        XCTAssertEqual(allTasks.count, 12)
        let numberOfExamTasks = allTasks.filter { $0.$exam.id != nil }
        XCTAssertEqual(numberOfExamTasks.count, 5)
    }

    static let allTests = [
        ("testCreate", testCreate),
        ("testSoftDelete", testSoftDelete)
    ]
}

extension Topic.Import {
    static func testData(chapter: Int, topicName: String) -> Topic.Import {
        Topic.Import(
            topic: Topic.Create.Data(subjectID: 0, name: topicName, chapter: chapter),
            subtopics: [
                Subtopic.Import(
                    subtopic: .init(name: "First", topicId: 0),
                    multipleChoiceTasks: [
                        MultipleChoiceTask.Import(
                            description: nil,
                            question: "Test", exam: Exam.Compact(subjectID: 0, type: .original, year: 2018),
                            isTestable: false,
                            isMultipleSelect: false,
                            choices: [MultipleChoiceTaskChoice.Create.Data(choice: "Hello", isCorrect: false), MultipleChoiceTaskChoice.Create.Data(choice: "Hello 2", isCorrect: false)],
                            solutions: [TaskSolution.Create.Data(solution: "Some Solution", presentUser: true, taskID: 0)]
                        )
                    ],
                    typingTasks: [
                        TypingTask.Import(
                            description: nil,
                            question: "Test",
                            exam: Exam.Compact(subjectID: 0, type: .original, year: 2019),
                            solutions: [TaskSolution.Create.Data(solution: "Some Solution", presentUser: true, taskID: 0)]
                        ),
                        TypingTask.Import(
                            description: nil,
                            question: "Test",
                            exam: Exam.Compact(subjectID: 0, type: .continuation, year: 2019),
                            solutions: [TaskSolution.Create.Data(solution: "Some Solution", presentUser: true, taskID: 0)]
                        ),
                        TypingTask.Import(
                            description: nil,
                            question: "Test",
                            exam: nil,
                            solutions: [TaskSolution.Create.Data(solution: "Some Solution", presentUser: true, taskID: 0)]
                        )
                    ]
                ),
                Subtopic.Import(
                    subtopic: .init(name: "Second", topicId: 0),
                    multipleChoiceTasks: [],
                    typingTasks: [
                        TypingTask.Import(
                            description: nil,
                            question: "Test",
                            exam: Exam.Compact(subjectID: 0, type: .original, year: 2019),
                            solutions: [TaskSolution.Create.Data(solution: "Some Solution", presentUser: true, taskID: 0)]
                        ),
                        TypingTask.Import(
                            description: nil,
                            question: "Test",
                            exam: Exam.Compact(subjectID: 0, type: .continuation, year: 2018),
                            solutions: [TaskSolution.Create.Data(solution: "Some Solution", presentUser: true, taskID: 0)]
                        ),
                        TypingTask.Import(
                            description: nil,
                            question: "Test",
                            exam: nil,
                            solutions: [TaskSolution.Create.Data(solution: "Some Solution", presentUser: true, taskID: 0)]
                        )
                    ]
                )
            ]
        )
    }
}
