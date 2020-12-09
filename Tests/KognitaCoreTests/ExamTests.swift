//
//  ExamTests.swift
//  KognitaCoreTests
//
//  Created by Mats Mollestad on 09/12/2020.
//

import XCTest
import Vapor
@testable import KognitaCore
import KognitaCoreTestable

class ExamTests: VaporTestCase {
    lazy var examRepository: ExamRepository = { TestableRepositories.testable(with: app).examRepository }()
    lazy var typingTaskRepository: TypingTaskRepository = { TestableRepositories.testable(with: app).typingTaskRepository }()
    lazy var multipleChoiceRepository: MultipleChoiseTaskRepository = { TestableRepositories.testable(with: app).multipleChoiceTaskRepository }()

    func testNumberOfTasks() throws {
        let user = try User.create(on: app)
        let subject = try Subject.create(on: app)
        let topic = try Topic.create(subjectId: subject.id, on: app.db)
        let subtopic = try Subtopic.create(topicId: topic.id, on: app.db)
        let exam = try Exam.create(subjectID: subject.id, type: .original, year: 2020, app: app)

        let numberOfTasks = 1

        for _ in 0..<numberOfTasks {
            _ = try MultipleChoiceTask.create(subtopic: subtopic, exam: exam, on: app)
            _ = try FlashCardTask.create(subtopic: subtopic, exam: exam, on: app)
        }
        for _ in 0..<numberOfTasks {
            _ = try MultipleChoiceTask.create(subtopic: subtopic, on: app)
            _ = try FlashCardTask.create(subtopic: subtopic, on: app)
        }
        for _ in 0..<numberOfTasks {
            let multipleChoice = try MultipleChoiceTask.create(subtopic: subtopic, exam: exam, on: app)
            let typingTask = try FlashCardTask.create(subtopic: subtopic, exam: exam, on: app)
            try typingTaskRepository.deleteModelWith(id: typingTask.id!, by: user).wait()
            try multipleChoiceRepository.deleteModelWith(id: multipleChoice.id, by: user).wait()
        }

        let exams = try examRepository.allExamsWithNumberOfTasksFor(subjectID: subject.id, userID: user.id).wait()

        XCTAssertEqual(exams.count, 1)
        let firstExam = try XCTUnwrap(exams.first)
        XCTAssertEqual(firstExam.numberOfTasks, numberOfTasks * 2)
    }
}
