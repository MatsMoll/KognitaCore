import Foundation
@testable import KognitaCore
import KognitaCoreTestable
import XCTest

@available(OSX 10.15, *)
class TestSessionTests: VaporTestCase {

    lazy var subjectTestRepository: SubjectTestRepositoring = { TestableRepositories.testable(with: app).subjectTestRepository }()
    lazy var testSessionRepository: TestSessionRepositoring = { TestableRepositories.testable(with: app).testSessionRepository }()

    func testSubmittingAndUpdatingAnswerMultipleUsers() throws {

        let userOne = try User.create(on: app)
        let userTwo = try User.create(on: app)

        do {
            let test = try setupTestWithTasks()

            let sessionOneEntry = try subjectTestRepository.enter(test: test, with: enterRequest, by: userOne).wait()
            let sessionTwoEntry = try subjectTestRepository.enter(test: test, with: enterRequest, by: userTwo).wait()

            let sessionOne = try TestSession.TestParameter.resolveWith(sessionOneEntry.id, database: database).wait()
            let sessionTwo = try TestSession.TestParameter.resolveWith(sessionTwoEntry.id, database: database).wait()

            try XCTAssertNotEqual(sessionOne.requireID(), sessionTwo.requireID())
            XCTAssertEqual(sessionOne.testID, test.id)
            XCTAssertEqual(sessionOne.userID, userOne.id)
            XCTAssertEqual(sessionTwo.testID, test.id)
            XCTAssertEqual(sessionTwo.userID, userTwo.id)

            let firstSubmit                 = try submittionAt(index: 1, for: test)
            var secondIncorrectSubmittion   = try submittionAt(index: 2, for: test, isCorrect: false)
            let secondCorrectSubmittion     = try submittionAt(index: 2, for: test, isCorrect: true)
            var thiredSubmit                = try submittionAt(index: 3, for: test)

            try testSessionRepository.submit(content: firstSubmit, sessionID: sessionOne.requireID(), by: userOne).wait()
            try testSessionRepository.submit(content: firstSubmit, sessionID: sessionOne.requireID(), by: userOne).wait()
            try testSessionRepository.submit(content: firstSubmit, sessionID: sessionTwo.requireID(), by: userTwo).wait()
            try testSessionRepository.submit(content: secondIncorrectSubmittion, sessionID: sessionOne.requireID(), by: userOne).wait()

            // Submitting a choise to a task that do not contain the choise
            secondIncorrectSubmittion.taskIndex = 1
            XCTAssertThrowsError(
                try testSessionRepository.submit(content: secondIncorrectSubmittion, sessionID: sessionOne.requireID(), by: userOne).wait()
            )
            // Submitting to a session that is not the user's
            XCTAssertThrowsError(
                try testSessionRepository.submit(content: secondCorrectSubmittion, sessionID: sessionOne.requireID(), by: userTwo).wait()
            )
            // Updating old submittion
            try testSessionRepository.submit(content: secondCorrectSubmittion, sessionID: sessionOne.requireID(), by: userOne).wait()

            try testSessionRepository.submit(content: thiredSubmit, sessionID: sessionOne.requireID(), by: userOne).wait()
            try testSessionRepository.submit(content: thiredSubmit, sessionID: sessionTwo.requireID(), by: userTwo).wait()

            thiredSubmit.taskIndex = 4
            XCTAssertThrowsError(
                try testSessionRepository
                    .submit(content: thiredSubmit, sessionID: sessionOne.requireID(), by: userOne).wait()
            )
            let answers         = try TaskSessionAnswer.query(on: database).all().wait()
            let flashAnswers    = try MultipleChoiseTaskAnswer.query(on: database).all().wait()
            let taskIDs         = Set(flashAnswers.map { $0.$choice.id })
            let sessionIDs      = Set(answers.map { $0.$session.id })
            let userSessions    = try Set([sessionOne.requireID(), sessionTwo.requireID()])

            XCTAssertEqual(userSessions, sessionIDs)
            XCTAssertEqual(answers.count, 5)
            XCTAssertEqual(flashAnswers.count, 5)
            XCTAssertEqual(taskIDs.count, 3)
        } catch {
            XCTFail(error.localizedDescription)
        }
    }

    func testUpdateAnswerInSession() throws {

        let user = try User.create(on: app)

        do {
            let test = try setupTestWithTasks()

            let sessionOneEntry = try subjectTestRepository.enter(test: test, with: enterRequest, by: user).wait()
            let sessionOne = try TestSession.TestParameter.resolveWith(sessionOneEntry.id, database: database).wait()

            let firstSubmittion             = try submittionAt(index: 1, for: test)
            let secondIncorrectSubmittion   = try submittionAt(index: 2, for: test, isCorrect: false)
            let secondCorrectSubmittion     = try submittionAt(index: 2, for: test, isCorrect: true)

            try testSessionRepository.submit(content: firstSubmittion, sessionID: sessionOne.requireID(), by: user).wait()
            try testSessionRepository.submit(content: secondIncorrectSubmittion, sessionID: sessionOne.requireID(), by: user).wait()
            // Updating old submittion
            try testSessionRepository.submit(content: secondCorrectSubmittion, sessionID: sessionOne.requireID(), by: user).wait()

            let answers = try TaskSessionAnswer.query(on: database).all().wait()
            let choises = try MultipleChoiseTaskAnswer.query(on: database).all().wait()
            let taskAnswers = try TaskAnswer.query(on: database).all().wait()

            let choisesIDs = Set(choises.map { $0.$choice.id })
            let submittedChoisesIDs = Set(firstSubmittion.choises + secondCorrectSubmittion.choises)

            XCTAssertEqual(taskAnswers.count, 2)
            XCTAssertEqual(answers.count, 2)
            XCTAssertEqual(choises.count, 2)
            XCTAssertEqual(choisesIDs, submittedChoisesIDs)
        } catch {
            XCTFail(error.localizedDescription)
        }
    }

    func testSubmittingTestSession() throws {

        let userOne = try User.create(on: app)
        let userTwo = try User.create(on: app)

        do {
            let test = try setupTestWithTasks()

            let sessionOneEntry = try subjectTestRepository.enter(test: test, with: enterRequest, by: userOne).wait()
            let sessionTwoEntry = try subjectTestRepository.enter(test: test, with: enterRequest, by: userTwo).wait()

            var sessionOne = try TestSession.TestParameter.resolveWith(sessionOneEntry.id, database: database).wait()
            var sessionTwo = try TestSession.TestParameter.resolveWith(sessionTwoEntry.id, database: database).wait()

            let firstSubmittion     = try submittionAt(index: 1, for: test)
            let secondSubmittion    = try submittionAt(index: 2, for: test)
            let thirdSubmittion     = try submittionAt(index: 3, for: test)

            try testSessionRepository.submit(content: firstSubmittion, sessionID: sessionOne.requireID(), by: userOne).wait()
            try testSessionRepository.submit(content: firstSubmittion, sessionID: sessionTwo.requireID(), by: userTwo).wait()

            try testSessionRepository.submit(content: secondSubmittion, sessionID: sessionOne.requireID(), by: userOne).wait()

            try testSessionRepository.submit(content: thirdSubmittion, sessionID: sessionOne.requireID(), by: userOne).wait()
            try testSessionRepository.submit(content: thirdSubmittion, sessionID: sessionTwo.requireID(), by: userTwo).wait()

            try testSessionRepository.submit(testID: sessionOne.requireID(), by: userOne).wait()

            var results = try TaskResult.DatabaseModel.query(on: database).all().wait()

            sessionOne = try TestSession.TestParameter.resolveWith(sessionOneEntry.id, database: database).wait()
            sessionTwo = try TestSession.TestParameter.resolveWith(sessionTwoEntry.id, database: database).wait()

            XCTAssertEqual(results.count, 3)
            XCTAssertNotNil(sessionOne.submittedAt)
            XCTAssertNil(sessionTwo.submittedAt)

            try testSessionRepository.submit(testID: sessionTwo.requireID(), by: userTwo).wait()
            results = try TaskResult.DatabaseModel.query(on: database).all().wait()

            sessionOne = try TestSession.TestParameter.resolveWith(sessionOneEntry.id, database: database).wait()
            sessionTwo = try TestSession.TestParameter.resolveWith(sessionTwoEntry.id, database: database).wait()

            XCTAssertEqual(results.count, 5)
            XCTAssertNotNil(sessionOne.submittedAt)
            XCTAssertNotNil(sessionTwo.submittedAt)
            XCTAssertEqual(results.filter({ $0.$session.id == sessionOneEntry.id }).count, 3)
            XCTAssertEqual(results.filter({ $0.$session.id == sessionTwoEntry.id }).count, 2)
            XCTAssert(results.allSatisfy({ $0.resultScore == 1 }), "One or more results was not recored as 100% correct")

            // Should throw when submtting an answer after submitting results
            XCTAssertThrowsError(
                try testSessionRepository.submit(content: thirdSubmittion, sessionID: sessionTwo.requireID(), by: userTwo).wait()
            )
            // Should throw when submtting the second time
            XCTAssertThrowsError(
                try testSessionRepository.submit(testID: sessionOne.requireID(), by: userOne).wait()
            )
        } catch {
            XCTFail(error.localizedDescription)
        }
    }

    func testResultsAfterSubmittion() throws {
        let test = try setupTestWithTasks()

        let userOne = try User.create(on: app)
        let userTwo = try User.create(on: app)
        let userThree = try User.create(on: app)

        let sessionOneEntry = try subjectTestRepository.enter(test: test, with: enterRequest, by: userOne).wait()
        let sessionTwoEntry = try subjectTestRepository.enter(test: test, with: enterRequest, by: userTwo).wait()

        let sessionOne = try TestSession.TestParameter.resolveWith(sessionOneEntry.id, database: database).wait()
        let sessionTwo = try TestSession.TestParameter.resolveWith(sessionTwoEntry.id, database: database).wait()

        let firstSubmittion     = try submittionAt(index: 1, for: test)
        let secondSubmittion    = try submittionAt(index: 2, for: test)
        let thirdSubmittion     = try submittionAt(index: 3, for: test)

        try testSessionRepository.submit(content: firstSubmittion, sessionID: sessionOne.requireID(), by: userOne).wait()
        try testSessionRepository.submit(content: firstSubmittion, sessionID: sessionTwo.requireID(), by: userTwo).wait()

        try testSessionRepository.submit(content: secondSubmittion, sessionID: sessionOne.requireID(), by: userOne).wait()

        try testSessionRepository.submit(content: thirdSubmittion, sessionID: sessionOne.requireID(), by: userOne).wait()
        try testSessionRepository.submit(content: thirdSubmittion, sessionID: sessionTwo.requireID(), by: userTwo).wait()

        try testSessionRepository.submit(testID: sessionOne.requireID(), by: userOne).wait()
        try testSessionRepository.submit(testID: sessionTwo.requireID(), by: userTwo).wait()

        let userOneResults = try testSessionRepository.results(in: sessionOne.requireID(), for: userOne).wait()
        let userTwoResults = try testSessionRepository.results(in: sessionTwo.requireID(), for: userTwo).wait()

        XCTAssertThrowsError(
            try testSessionRepository.results(in: sessionOne.requireID(), for: userThree).wait()
        )
        XCTAssertThrowsError(
            try testSessionRepository.results(in: sessionOne.requireID(), for: userTwo).wait()
        )

        XCTAssertEqual(userOneResults.score, 3)
        XCTAssertEqual(userOneResults.scoreProsentage, 1)
        XCTAssertEqual(userOneResults.maximumScore, 3)

        XCTAssertEqual(userTwoResults.score, 2)
        XCTAssertEqual(userTwoResults.scoreProsentage, 2/3)
        XCTAssertEqual(userTwoResults.maximumScore, 3)
    }

    func testOverview() throws {
        let test = try setupTestWithTasks()

        let userOne = try User.create(on: app)
        let userTwo = try User.create(on: app)
        let userThree = try User.create(on: app)

        let sessionOneEntry = try subjectTestRepository.enter(test: test, with: enterRequest, by: userOne).wait()
        let sessionTwoEntry = try subjectTestRepository.enter(test: test, with: enterRequest, by: userTwo).wait()

        let sessionOne = try TestSession.TestParameter.resolveWith(sessionOneEntry.id, database: database).wait()
        let sessionTwo = try TestSession.TestParameter.resolveWith(sessionTwoEntry.id, database: database).wait()

        let firstSubmittion     = try submittionAt(index: 1, for: test)
        let secondSubmittion    = try submittionAt(index: 2, for: test)
        let thirdSubmittion     = try submittionAt(index: 3, for: test)

        try testSessionRepository.submit(content: firstSubmittion, sessionID: sessionOne.requireID(), by: userOne).wait()
        try testSessionRepository.submit(content: firstSubmittion, sessionID: sessionTwo.requireID(), by: userTwo).wait()

        try testSessionRepository.submit(content: secondSubmittion, sessionID: sessionOne.requireID(), by: userOne).wait()

        try testSessionRepository.submit(content: thirdSubmittion, sessionID: sessionOne.requireID(), by: userOne).wait()
        try testSessionRepository.submit(content: thirdSubmittion, sessionID: sessionTwo.requireID(), by: userTwo).wait()

        let overviewOne = try testSessionRepository.overview(in: sessionOne, for: userOne).wait()
        let overviewTwo = try testSessionRepository.overview(in: sessionTwo, for: userTwo).wait()

        XCTAssertThrowsError(
            try testSessionRepository.overview(in: sessionTwo, for: userThree).wait()
        )

        XCTAssertEqual(overviewOne.test.id, test.id)
        XCTAssertEqual(overviewOne.tasks.count, 3)
        XCTAssertEqual(overviewOne.tasks.filter({ $0.isAnswered }).count, 3)

        XCTAssertEqual(overviewTwo.test.id, test.id)
        XCTAssertEqual(overviewTwo.tasks.count, 3)
        XCTAssertEqual(overviewTwo.tasks.filter({ $0.isAnswered }).count, 2)
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
            .filter(\.$test.$id == test.id)
            .filter(\.$id == index)
            .join(MultipleChoiseTaskChoise.self, on: \MultipleChoiseTaskChoise.$task.$id == \SubjectTest.Pivot.Task.$task.$id)
            .all(MultipleChoiseTaskChoise.self)
            .wait()
    }

    func multipleChoiseAnswer(with choises: [MultipleChoiseTaskChoise.IDValue]) -> MultipleChoiceTask.Submit {
        .init(
            timeUsed: .seconds(20),
            choises: choises,
            taskIndex: 1
        )
    }

    func setupTestWithTasks(scheduledAt: Date = .now, duration: TimeInterval = .minutes(10), numberOfTasks: Int = 3) throws -> SubjectTest {
        let topic = try Topic.create(on: app)
        let subtopic = try Subtopic.create(topic: topic, on: app)
        let taskIds = try (0..<numberOfTasks).map { _ in
            try MultipleChoiceTask.create(subtopic: subtopic, on: app).id
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
        ("testUpdateAnswerInSession", testUpdateAnswerInSession),
        ("testSubmittingAndUpdatingAnswerMultipleUsers", testSubmittingAndUpdatingAnswerMultipleUsers),
        ("testSubmittingTestSession", testSubmittingTestSession),
        ("testResultsAfterSubmittion", testResultsAfterSubmittion),
        ("testOverview", testOverview)
    ]
}
