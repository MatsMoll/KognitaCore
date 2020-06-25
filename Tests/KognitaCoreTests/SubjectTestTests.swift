import Foundation
@testable import KognitaCore
import KognitaCoreTestable
import XCTest
import FluentKit

//swiftlint:disable type_body_length

@available(OSX 10.15, *)
class SubjectTestTests: VaporTestCase {

    lazy var subjectTestRepository: SubjectTestRepositoring = { TestableRepositories.testable(with: database).subjectTestRepository }()
    lazy var testSessionRepository: TestSessionRepositoring = { TestableRepositories.testable(with: database).testSessionRepository }()

    func testCreateTest() throws {

        let scheduledAt: Date = .now
        let duration: TimeInterval = .minutes(20)
        let numberOfTasks = 3

        do {
            let test = try setupTestWithTasks(
                scheduledAt: scheduledAt,
                duration: duration,
                numberOfTasks: numberOfTasks
            )
            let testTasks = try SubjectTest.Pivot.Task
                .query(on: database)
                .all()
                .wait()

            XCTAssertEqual(test.scheduledAt, scheduledAt)
            XCTAssertEqual(test.duration, duration)
            XCTAssertEqual(testTasks.count, numberOfTasks)
        } catch {
            XCTFail(error.localizedDescription)
        }
    }

    func testCreateTestUnauthorized() {
        let data = SubjectTest.Create.Data(
            tasks: [],
            subjectID: 1,
            duration: .minutes(10),
            scheduledAt: .now,
            password: "password",
            title: "Testing",
            isTeamBasedLearning: false
        )
        XCTAssertThrowsError(
            _ = try subjectTestRepository.create(from: data, by: nil).wait()
        )
    }

    func testCreateTestUnprivileged() throws {
        let user = try User.create(isAdmin: false, on: app)
        let data = SubjectTest.Create.Data(
            tasks: [],
            subjectID: 1,
            duration: .minutes(10),
            scheduledAt: .now,
            password: "password",
            title: "Testing",
            isTeamBasedLearning: false
        )
        XCTAssertThrowsError(
            _ = try subjectTestRepository.create(from: data, by: user).wait()
        )
    }

    func testOpeningTestWhenUnprivileged() throws {
        let user = try User.create(isAdmin: false, on: app)

        let test = try setupTestWithTasks()
        XCTAssertThrowsError(
            try subjectTestRepository.open(test: test, by: user).wait()
        )
    }

    func testEnteringTestWhenClosed() throws {

        let user = try User.create(on: app)

        do {
            let test = try setupTestWithTasks(
                scheduledAt: Date().addingTimeInterval(.minutes(2))
            )
            XCTAssertThrowsError(
                try subjectTestRepository
                    .enter(test: test, with: enterRequest, by: user).wait()
            )
        } catch {
            XCTFail(error.localizedDescription)
        }
    }

    func testEnteringWithIncorrectPassword() throws {

        let user = try User.create(on: app)

        do {
            let test = try setupTestWithTasks()
            XCTAssertThrowsError(
                try subjectTestRepository
                    .enter(test: test, with: .init(password: "incorrect"), by: user).wait()
            )
        } catch {
            XCTFail(error.localizedDescription)
        }
    }

    func testEnteringMultipleTimes() throws {

        let userOne = try User.create(on: app)
        let userTwo = try User.create(on: app)

        do {
            let test = try setupTestWithTasks()

            let sessionOneEntry = try subjectTestRepository.enter(test: test, with: enterRequest, by: userOne).wait()
            let sessionTwoEntry = try subjectTestRepository.enter(test: test, with: enterRequest, by: userTwo).wait()

            let sessionOne = try TestSession.TestParameter.resolveWith(sessionOneEntry.id, database: database).wait()
            let sessionTwo = try TestSession.TestParameter.resolveWith(sessionTwoEntry.id, database: database).wait()

            XCTAssertEqual(sessionOne.testID, test.id)
            XCTAssertEqual(sessionOne.userID, userOne.id)
            XCTAssertEqual(sessionTwo.testID, test.id)
            XCTAssertEqual(sessionTwo.userID, userTwo.id)

            XCTAssertThrowsError(
                _ = try subjectTestRepository
                    .enter(test: test, with: enterRequest, by: userOne).wait()
            )

            let sessions = try TestSession.DatabaseModel.query(on: database).all().wait()
            XCTAssertEqual(sessions.count, 2)
        } catch {
            XCTFail(error.localizedDescription)
        }
    }

    func testCompletionStatus() {
        do {
            let test = try setupTestWithTasks()

            let teacher = try User.create(on: app)
            let userOne = try User.create(isAdmin: false, on: app)
            let userTwo = try User.create(isAdmin: false, on: app)

            let sessionOneEntry = try subjectTestRepository.enter(test: test, with: enterRequest, by: userOne).wait()
            let sessionTwoEntry = try subjectTestRepository.enter(test: test, with: enterRequest, by: userTwo).wait()

            let sessionOne = try TestSession.TestParameter.resolveWith(sessionOneEntry.id, database: database).wait()
            let sessionTwo = try TestSession.TestParameter.resolveWith(sessionTwoEntry.id, database: database).wait()

            var status = try subjectTestRepository.userCompletionStatus(in: test, user: teacher).wait()

            // Students / users should not be able to see the completion status of the test
            XCTAssertThrowsError(
                try subjectTestRepository.userCompletionStatus(in: test, user: userOne).wait()
            )

            XCTAssertEqual(status.amountOfEnteredUsers, 2)
            XCTAssertEqual(status.amountOfCompletedUsers, 0)
            XCTAssertEqual(status.hasEveryoneCompleted, false)

            try testSessionRepository.submit(test: sessionOne, by: userOne).wait()

            status = try subjectTestRepository.userCompletionStatus(in: test, user: teacher).wait()

            XCTAssertEqual(status.amountOfEnteredUsers, 2)
            XCTAssertEqual(status.amountOfCompletedUsers, 1)
            XCTAssertEqual(status.hasEveryoneCompleted, false)

            try testSessionRepository.submit(test: sessionTwo, by: userTwo).wait()

            status = try subjectTestRepository.userCompletionStatus(in: test, user: teacher).wait()

            XCTAssertEqual(status.amountOfEnteredUsers, 2)
            XCTAssertEqual(status.amountOfCompletedUsers, 2)
            XCTAssertEqual(status.hasEveryoneCompleted, true)
        } catch {
            XCTFail(error.localizedDescription)
        }
    }

    func testRetrivingTaskContent() throws {
        failableTest {
            let test = try setupTestWithTasks(numberOfTasks: 3)

            XCTAssertTrue(test.isOpen)

            let userOne = try User.create(isAdmin: false, on: app)
            let userTwo = try User.create(isAdmin: false, on: app)

            let sessionOneEntry = try subjectTestRepository.enter(test: test, with: enterRequest, by: userOne).wait()
            let sessionTwoEntry = try subjectTestRepository.enter(test: test, with: enterRequest, by: userTwo).wait()

            let sessionOne = try TestSession.TestParameter.resolveWith(sessionOneEntry.id, database: database).wait()
            let sessionTwo = try TestSession.TestParameter.resolveWith(sessionTwoEntry.id, database: database).wait()

            let firstSubmittion     = try submittionAt(index: 1, for: test)
            let secondSubmittion    = try submittionAt(index: 2, for: test, isCorrect: false)

            var userOneTaskContent = try subjectTestRepository.taskWith(id: 1, in: sessionOne, for: userOne).wait()
            var userTwoTaskContent = try subjectTestRepository.taskWith(id: 1, in: sessionTwo, for: userTwo).wait()

            XCTAssertEqual(userOneTaskContent.testTasks.count, 3)
            XCTAssertEqual(userOneTaskContent.testTasks.first?.isCurrent, true)
            XCTAssertEqual(userOneTaskContent.testTasks.last?.isCurrent, false)
            XCTAssertTrue(userOneTaskContent.choises.allSatisfy({ $0.isSelected == false }))

            XCTAssertEqual(userTwoTaskContent.testTasks.count, 3)
            XCTAssertEqual(userTwoTaskContent.testTasks.first?.isCurrent, true)
            XCTAssertEqual(userTwoTaskContent.testTasks.last?.isCurrent, false)
            XCTAssertTrue(userTwoTaskContent.choises.allSatisfy({ $0.isSelected == false }))

            try testSessionRepository.submit(content: firstSubmittion, for: sessionOne, by: userOne).wait()
            try testSessionRepository.submit(content: secondSubmittion, for: sessionTwo, by: userTwo).wait()

            userOneTaskContent = try subjectTestRepository.taskWith(id: 1, in: sessionOne, for: userOne).wait()
            userTwoTaskContent = try subjectTestRepository.taskWith(id: 1, in: sessionTwo, for: userTwo).wait()

            XCTAssertEqual(userOneTaskContent.testTasks.count, 3)
            XCTAssertEqual(userOneTaskContent.testTasks.first?.isCurrent, true)
            XCTAssertEqual(userOneTaskContent.testTasks.last?.isCurrent, false)
            XCTAssertEqual(userOneTaskContent.choises.count, 3)
            XCTAssertEqual(userOneTaskContent.choises.filter({ $0.isCorrect && $0.isSelected }).count, 1)

            XCTAssertEqual(userTwoTaskContent.testTasks.count, 3)
            XCTAssertEqual(userTwoTaskContent.testTasks.first?.isCurrent, true)
            XCTAssertEqual(userTwoTaskContent.testTasks.last?.isCurrent, false)
            XCTAssertTrue(userTwoTaskContent.choises.allSatisfy({ $0.isSelected == false }))

            userTwoTaskContent = try subjectTestRepository.taskWith(id: 2, in: sessionTwo, for: userTwo).wait()

            XCTAssertEqual(userTwoTaskContent.testTasks.count, 3)
            XCTAssertEqual(userTwoTaskContent.testTasks.filter({ $0.testTaskID == 2 }).first?.isCurrent, true)
            XCTAssertEqual(userTwoTaskContent.choises.count, 3)
            XCTAssertEqual(userTwoTaskContent.choises.filter({ $0.isSelected && $0.isCorrect == false }).count, 2)

            XCTAssertThrowsError(
                try subjectTestRepository.taskWith(id: 1, in: sessionTwo, for: userOne).wait()
            )
        }
    }

    func testResultStatistics() {
        do {
            let test = try setupTestWithTasks()

            let teacher = try User.create(on: app)
            let userOne = try User.create(isAdmin: false, on: app)
            let userTwo = try User.create(isAdmin: false, on: app)

            let firstSubmittion             = try submittionAt(index: 1, for: test)
            let secondSubmittion            = try submittionAt(index: 2, for: test)
            let secondSubmittionIncorrect   = try submittionAt(index: 2, for: test, isCorrect: false)
            let thirdSubmittion             = try submittionAt(index: 3, for: test)

            let firstTaskID     = try taskID(for: firstSubmittion.taskIndex)
            let secondTaskID    = try taskID(for: secondSubmittion.taskIndex)
            let thirdTaskID     = try taskID(for: thirdSubmittion.taskIndex)

            try submitTestWithAnswers(test, for: userOne, with: [firstSubmittion, secondSubmittionIncorrect, secondSubmittion, thirdSubmittion])
            try submitTestWithAnswers(test, for: userTwo, with: [firstSubmittion, secondSubmittionIncorrect, thirdSubmittion])

            let result = try subjectTestRepository.results(for: test, user: teacher).wait()

            XCTAssertEqual(result.title, test.title)
            XCTAssertEqual(result.heldAt, test.openedAt)

            let firstTaskResult = try XCTUnwrap(result.taskResults.first(where: { $0.taskID == firstTaskID }))
            XCTAssertEqual(firstTaskResult.choises.count, 3)
            XCTAssertTrue(firstTaskResult.choises.contains(where: { $0.numberOfSubmissions == 2 }))
            XCTAssertTrue(firstTaskResult.choises.contains(where: { $0.percentage == 1 }))
            XCTAssertTrue(firstTaskResult.choises.contains(where: { $0.percentage == 0 }))

            let secondTaskResult = try XCTUnwrap(result.taskResults.first(where: { $0.taskID == secondTaskID }))
            XCTAssertEqual(secondTaskResult.choises.count, 3)
            XCTAssertTrue(secondTaskResult.choises.allSatisfy({ $0.numberOfSubmissions == 1 }))
            XCTAssertTrue(secondTaskResult.choises.allSatisfy({ $0.percentage == 1/3 }))

            let thirdTaskResult = try XCTUnwrap(result.taskResults.first(where: { $0.taskID == thirdTaskID }))
            XCTAssertEqual(thirdTaskResult.choises.count, 3)
            XCTAssertTrue(thirdTaskResult.choises.contains(where: { $0.numberOfSubmissions == 2 }))
            XCTAssertTrue(thirdTaskResult.choises.contains(where: { $0.percentage == 1 }))
            XCTAssertTrue(thirdTaskResult.choises.contains(where: { $0.percentage == 0 }))

            XCTAssertThrowsError(
                try subjectTestRepository.results(for: test, user: userOne).wait()
            )
        } catch {
            XCTFail(error.localizedDescription)
        }
    }

    func testResultStatisticsTaskReuseBug() {
        do {
            let test = try setupTestWithTasks()

            let teacher = try User.create(on: app)
            let userOne = try User.create(isAdmin: false, on: app)
            let userTwo = try User.create(isAdmin: false, on: app)

            let firstSubmittion             = try submittionAt(index: 1, for: test)
            let secondSubmittion            = try submittionAt(index: 2, for: test)
            let secondSubmittionIncorrect   = try submittionAt(index: 2, for: test, isCorrect: false)
            let thirdSubmittion             = try submittionAt(index: 3, for: test)

            let firstTaskID     = try taskID(for: firstSubmittion.taskIndex)
            let secondTaskID    = try taskID(for: secondSubmittion.taskIndex)
            let thirdTaskID     = try taskID(for: thirdSubmittion.taskIndex)

            let secondTest = try setupTestWithTasks(with: [firstTaskID, secondTaskID, thirdTaskID], subjectID: test.subjectID)

            try submitTestWithAnswers(test, for: userOne, with: [firstSubmittion, secondSubmittionIncorrect, secondSubmittion, thirdSubmittion])
            try submitTestWithAnswers(test, for: userTwo, with: [firstSubmittion, secondSubmittionIncorrect])

            let result = try subjectTestRepository.results(for: test, user: teacher).wait()

            try submitTestWithAnswers(secondTest, for: userOne, with: [firstSubmittion, secondSubmittionIncorrect, secondSubmittion, thirdSubmittion])
            try submitTestWithAnswers(secondTest, for: userTwo, with: [firstSubmittion, secondSubmittion])

            let secondResult = try subjectTestRepository.results(for: secondTest, user: teacher).wait()

            XCTAssertEqual(secondResult.title, secondTest.title)
            XCTAssertEqual(secondResult.heldAt, secondTest.openedAt)

            let firstTaskResult = try XCTUnwrap(secondResult.taskResults.first(where: { $0.taskID == firstTaskID }))
            XCTAssertEqual(firstTaskResult.choises.count, 3)
            XCTAssertTrue(firstTaskResult.choises.contains(where: { $0.numberOfSubmissions == 2 }))
            XCTAssertTrue(firstTaskResult.choises.contains(where: { $0.percentage == 1 }))
            XCTAssertTrue(firstTaskResult.choises.contains(where: { $0.percentage == 0 }))

            let secondTaskResult = try XCTUnwrap(result.taskResults.first(where: { $0.taskID == secondTaskID }))
            XCTAssertEqual(secondTaskResult.choises.count, 3)
            XCTAssertTrue(secondTaskResult.choises.allSatisfy({ $0.numberOfSubmissions == 1 }))
            XCTAssertTrue(secondTaskResult.choises.allSatisfy({ $0.percentage == 1/3 }))

            let thirdTaskResult = try XCTUnwrap(result.taskResults.first(where: { $0.taskID == thirdTaskID }))
            XCTAssertEqual(thirdTaskResult.choises.count, 3)
            XCTAssertTrue(thirdTaskResult.choises.contains(where: { $0.numberOfSubmissions == 1 }))
            XCTAssertTrue(thirdTaskResult.choises.contains(where: { $0.percentage == 1 }))
            XCTAssertTrue(thirdTaskResult.choises.contains(where: { $0.percentage == 0 }))

            XCTAssertThrowsError(
                try subjectTestRepository.results(for: test, user: userOne).wait()
            )
        } catch {
            XCTFail(error.localizedDescription)
        }
    }

    func testResultStatisticsTaskWithMultipleCorrectAnswers() {
        do {
            let choises: [MultipleChoiceTaskChoice.Create.Data] = [
                .init(choice: "first", isCorrect: false),
                .init(choice: "correct", isCorrect: true),
                .init(choice: "yeah", isCorrect: true)
            ]

            let test = try setupTestWithTasks(choises: choises)

            let teacher = try User.create(on: app)
            let userOne = try User.create(isAdmin: false, on: app)
            let userTwo = try User.create(isAdmin: false, on: app)

            let firstSubmittion             = try submittionAt(index: 1, for: test)
            let secondSubmittion            = try submittionAt(index: 2, for: test)
            let secondSubmittionIncorrect   = try submittionAt(index: 2, for: test, isCorrect: false)
            let thirdSubmittion             = try submittionAt(index: 3, for: test)

            let firstTaskID     = try taskID(for: firstSubmittion.taskIndex)
            let secondTaskID    = try taskID(for: secondSubmittion.taskIndex)
            let thirdTaskID     = try taskID(for: thirdSubmittion.taskIndex)

            let secondTest = try setupTestWithTasks(with: [firstTaskID, secondTaskID, thirdTaskID], subjectID: test.subjectID)

            try submitTestWithAnswers(test, for: userTwo, with: [firstSubmittion, secondSubmittionIncorrect])
            try submitTestWithAnswers(secondTest, for: userOne, with: [firstSubmittion, secondSubmittion, thirdSubmittion])

            let result = try subjectTestRepository.results(for: test, user: teacher).wait()
            let secondResult = try subjectTestRepository.results(for: secondTest, user: teacher).wait()

            XCTAssertEqual(result.averageScore, 1/3)
            XCTAssertEqual(secondResult.averageScore, 1)

            XCTAssertThrowsError(
                try subjectTestRepository.results(for: test, user: userOne).wait()
            )
        } catch {
            XCTFail(error.localizedDescription)
        }
    }

    func testTestResultHistogram() throws {
        do {
            let test = try setupTestWithTasks()

            let admin = try User.create(on: app)
            let userOne = try User.create(isAdmin: false, on: app)
            let userTwo = try User.create(isAdmin: false, on: app)

            let firstSubmittion             = try submittionAt(index: 1, for: test)
            let secondSubmittion            = try submittionAt(index: 2, for: test)
            let secondSubmittionIncorrect   = try submittionAt(index: 2, for: test, isCorrect: false)
            let thirdSubmittion             = try submittionAt(index: 3, for: test)

            try submitTestWithAnswers(test, for: userOne, with: [firstSubmittion, secondSubmittionIncorrect, secondSubmittion, thirdSubmittion])
            try submitTestWithAnswers(test, for: userTwo, with: [firstSubmittion, secondSubmittionIncorrect])

            let histogram = try subjectTestRepository.scoreHistogram(for: test, user: admin).wait()

            XCTAssertThrowsError(
                try subjectTestRepository.scoreHistogram(for: test, user: userOne).wait()
            )

            XCTAssertEqual(histogram.scores.count, 4)

            XCTAssertEqual(histogram.scores.first(where: { $0.score == 3 })?.amount, 1)
            XCTAssertEqual(histogram.scores.first(where: { $0.score == 2 })?.amount, 0)
            XCTAssertEqual(histogram.scores.first(where: { $0.score == 1 })?.amount, 1)
            XCTAssertEqual(histogram.scores.first(where: { $0.score == 0 })?.amount, 0)

            XCTAssertEqual(histogram.scores.first(where: { $0.score == 3 })?.percentage, 0.5)
            XCTAssertEqual(histogram.scores.first(where: { $0.score == 2 })?.percentage, 0)
            XCTAssertEqual(histogram.scores.first(where: { $0.score == 1 })?.percentage, 0.5)
            XCTAssertEqual(histogram.scores.first(where: { $0.score == 0 })?.percentage, 0)
        } catch {
            XCTFail(error.localizedDescription)
        }
    }

    func testUserResults() {
        do {
            let test = try setupTestWithTasks()

            let admin = try User.create(on: app)
            let userOne = try User.create(isAdmin: false, on: app)
            let userTwo = try User.create(isAdmin: false, on: app)

            let firstSubmittion             = try submittionAt(index: 1, for: test)
            let secondSubmittion            = try submittionAt(index: 2, for: test)
            let secondSubmittionIncorrect   = try submittionAt(index: 2, for: test, isCorrect: false)
            let thirdSubmittion             = try submittionAt(index: 3, for: test)

            try submitTestWithAnswers(test, for: userOne, with: [firstSubmittion, secondSubmittionIncorrect, secondSubmittion, thirdSubmittion])
            try submitTestWithAnswers(test, for: userTwo, with: [firstSubmittion, secondSubmittionIncorrect])

            let results = try subjectTestRepository.detailedUserResults(for: test, maxScore: 3, user: admin).wait()

            XCTAssertThrowsError(
                try subjectTestRepository.detailedUserResults(for: test, maxScore: 3, user: userOne).wait()
            )

            XCTAssertEqual(results.count, 2)

            let userOneResult = try XCTUnwrap(results.first(where: { $0.userEmail == userOne.email }))
            let userTwoResult = try XCTUnwrap(results.first(where: { $0.userEmail == userTwo.email }))

            XCTAssertEqual(userOneResult.score, 3)
            XCTAssertEqual(userTwoResult.score, 1)
            XCTAssertEqual(userOneResult.percentage, 1)
            XCTAssertEqual(userTwoResult.percentage, 1/3)
        } catch {
            XCTFail(error.localizedDescription)
        }
    }

    func submitTestWithAnswers(_ test: SubjectTest, for user: User, with submittions: [MultipleChoiceTask.Submit]) throws {
        let sessionEntry = try subjectTestRepository.enter(test: test, with: enterRequest, by: user).wait()

        let session = try TestSession.TestParameter.resolveWith(sessionEntry.id, database: database).wait()

        try submittions.forEach {
            try testSessionRepository.submit(content: $0, for: session, by: user).wait()
        }

        try testSessionRepository.submit(test: session, by: user).wait()
    }

    func submittionAt(index: Int, for test: SubjectTest, isCorrect: Bool = true) throws -> MultipleChoiceTask.Submit {
        let choises = try choisesAt(index: index, for: test)
        return try MultipleChoiceTask.Submit(
            timeUsed: .seconds(20),
            choises: choises.filter { $0.isCorrect == isCorrect }.map { try $0.requireID() },
            taskIndex: index
        )
    }

    func choisesAt(index: Int, for test: SubjectTest) throws -> [MultipleChoiseTaskChoise] {
        try SubjectTest.Pivot.Task
            .query(on: database)
            .sort(\.$createdAt)
            .filter(\SubjectTest.Pivot.Task.$test.$id == test.id)
            .filter(\.$id == index)
            .join(MultipleChoiseTaskChoise.self, on: \MultipleChoiseTaskChoise.$task.$id == \SubjectTest.Pivot.Task.$task.$id)
            .all(MultipleChoiseTaskChoise.self)
            .wait()
    }

    func taskID(for subjectTaskID: SubjectTest.Pivot.Task.IDValue) throws -> TaskDatabaseModel.IDValue {
        try SubjectTest.Pivot.Task
            .find(subjectTaskID, on: database)
            .unwrap(or: Errors.badTest)
            .map { $0.$task.id }
            .wait()
    }

    func multipleChoiseAnswer(with choises: [MultipleChoiceTaskChoice.ID]) -> MultipleChoiceTask.Submit {
        .init(
            timeUsed: .seconds(20),
            choises: choises,
            taskIndex: 1
        )
    }

    func setupTestWithTasks(with taskIDs: [MultipleChoiceTask.ID], subjectID: Subject.ID, scheduledAt: Date = .now, duration: TimeInterval = .minutes(10)) throws -> SubjectTest {
        let user = try User.create(on: app)

        let data = SubjectTest.Create.Data(
            tasks: taskIDs,
            subjectID: subjectID,
            duration: duration,
            scheduledAt: scheduledAt,
            password: "password",
            title: "Testing",
            isTeamBasedLearning: false
        )

        if scheduledAt.timeIntervalSinceNow < 0 {
            let test = try subjectTestRepository.create(from: data, by: user).wait()
            return try subjectTestRepository.open(test: test, by: user).wait()
        } else {
            return try subjectTestRepository.create(from: data, by: user).wait()
        }
    }

    func setupTestWithTasks(scheduledAt: Date = .now, duration: TimeInterval = .minutes(10), numberOfTasks: Int = 3, choises: [MultipleChoiceTaskChoice.Create.Data] = MultipleChoiceTaskChoice.Create.Data.standard) throws -> SubjectTest {
        let topic = try Topic.create(on: app)
        let subtopic = try Subtopic.create(topic: topic, on: app)
        let isMultipleSelect = choises.filter({ $0.isCorrect }).count > 1
        let taskIds = try (0..<numberOfTasks).map { _ in
            try MultipleChoiceTask.create(subtopic: subtopic, isMultipleSelect: isMultipleSelect, choises: choises, on: app)
                .id
        }
        _ = try MultipleChoiceTask.create(subtopic: subtopic, on: app)
        _ = try MultipleChoiceTask.create(subtopic: subtopic, on: app)
        _ = try MultipleChoiceTask.create(subtopic: subtopic, on: app)

        let user = try User.create(on: app)

        let data = SubjectTest.Create.Data(
            tasks: taskIds,
            subjectID: topic.subjectID,
            duration: duration,
            scheduledAt: scheduledAt,
            password: "password",
            title: "Testing",
            isTeamBasedLearning: false
        )

        if scheduledAt.timeIntervalSinceNow < 0 {
            let test = try subjectTestRepository.create(from: data, by: user).wait()
            return try subjectTestRepository.open(test: test, by: user).wait()
        } else {
            return try subjectTestRepository.create(from: data, by: user).wait()
        }
    }

    var enterRequest: SubjectTest.Enter.Request {
        .init(password: "password")
    }

    static let allTests = [
        ("testCreateTest", testCreateTest),
        ("testCreateTestUnauthorized", testCreateTestUnauthorized),
        ("testCreateTestUnprivileged", testCreateTestUnprivileged),
        ("testOpeningTestWhenUnprivileged", testOpeningTestWhenUnprivileged),
        ("testEnteringTestWhenClosed", testEnteringTestWhenClosed),
        ("testEnteringWithIncorrectPassword", testEnteringWithIncorrectPassword),
        ("testEnteringMultipleTimes", testEnteringMultipleTimes),
        ("testCompletionStatus", testCompletionStatus),
        ("testRetrivingTaskContent", testRetrivingTaskContent),
        ("testResultStatistics", testResultStatistics),
        ("testResultStatisticsTaskReuseBug", testResultStatisticsTaskReuseBug),
        ("testTestResultHistogram", testTestResultHistogram),
        ("testUserResults", testUserResults)
    ]
}

extension TimeInterval {

    static func minutes(_ time: Int) -> Double {
        Double(time) * 60
    }

    static func seconds(_ time: Int) -> Double {
        Double(time)
    }
}
