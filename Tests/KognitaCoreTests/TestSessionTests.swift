import Foundation
@testable import KognitaCore
import KognitaCoreTestable
import XCTest

@available(OSX 10.15, *)
class TestSessionTests: VaporTestCase {

    lazy var subjectTestRepository: some SubjectTestRepositoring = { SubjectTest.DatabaseRepository(conn: conn) }()
    lazy var testSessionRepository: some TestSessionRepositoring = { TestSession.DatabaseRepository(conn: conn) }()

    func testSubmittingAndUpdatingAnswerMultipleUsers() throws {

        let userOne = try User.create(on: conn)
        let userTwo = try User.create(on: conn)

        do {
            let test = try setupTestWithTasks()

            let sessionOneEntry = try subjectTestRepository.enter(test: test, with: enterRequest, by: userOne).wait()
            let sessionTwoEntry = try subjectTestRepository.enter(test: test, with: enterRequest, by: userTwo).wait()

            let sessionOne = try TaskSession.TestParameter.resolveParameter("\(sessionOneEntry.id)", conn: conn).wait()
            let sessionTwo = try TaskSession.TestParameter.resolveParameter("\(sessionTwoEntry.id)", conn: conn).wait()

            try XCTAssertNotEqual(sessionOne.requireID(), sessionTwo.requireID())
            XCTAssertEqual(sessionOne.testID, test.id)
            XCTAssertEqual(sessionOne.userID, userOne.id)
            XCTAssertEqual(sessionTwo.testID, test.id)
            XCTAssertEqual(sessionTwo.userID, userTwo.id)

            let firstSubmit                 = try submittionAt(index: 1, for: test)
            var secondIncorrectSubmittion   = try submittionAt(index: 2, for: test, isCorrect: false)
            let secondCorrectSubmittion     = try submittionAt(index: 2, for: test, isCorrect: true)
            var thiredSubmit                = try submittionAt(index: 3, for: test)

            try testSessionRepository.submit(content: firstSubmit, for: sessionOne, by: userOne).wait()
            try testSessionRepository.submit(content: firstSubmit, for: sessionTwo, by: userTwo).wait()
            try testSessionRepository.submit(content: secondIncorrectSubmittion, for: sessionOne, by: userOne).wait()

            // Submitting a choise to a task that do not contain the choise
            secondIncorrectSubmittion.taskIndex = 1
            XCTAssertThrowsError(
                try testSessionRepository.submit(content: secondIncorrectSubmittion, for: sessionOne, by: userOne).wait()
            )
            // Submitting to a session that is not the user's
            XCTAssertThrowsError(
                try testSessionRepository.submit(content: secondCorrectSubmittion, for: sessionOne, by: userTwo).wait()
            )
            // Updating old submittion
            try testSessionRepository.submit(content: secondCorrectSubmittion, for: sessionOne, by: userOne).wait()

            try testSessionRepository.submit(content: thiredSubmit, for: sessionOne, by: userOne).wait()
            try testSessionRepository.submit(content: thiredSubmit, for: sessionTwo, by: userTwo).wait()

            thiredSubmit.taskIndex = 4
            XCTAssertThrowsError(
                try testSessionRepository
                    .submit(content: thiredSubmit, for: sessionOne, by: userOne).wait()
            )
            let answers         = try TaskSessionAnswer.query(on: conn).all().wait()
            let flashAnswers    = try MultipleChoiseTaskAnswer.query(on: conn).all().wait()
            let taskIDs         = Set(flashAnswers.map { $0.choiseID })
            let sessionIDs      = Set(answers.map { $0.sessionID })
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

        let user = try User.create(on: conn)

        do {
            let test = try setupTestWithTasks()

            let sessionOneEntry = try subjectTestRepository.enter(test: test, with: enterRequest, by: user).wait()
            let sessionOne = try TaskSession.TestParameter.resolveParameter("\(sessionOneEntry.id)", conn: conn).wait()

            let firstSubmittion             = try submittionAt(index: 1, for: test)
            let secondIncorrectSubmittion   = try submittionAt(index: 2, for: test, isCorrect: false)
            let secondCorrectSubmittion     = try submittionAt(index: 2, for: test, isCorrect: true)

            try testSessionRepository.submit(content: firstSubmittion, for: sessionOne, by: user).wait()
            try testSessionRepository.submit(content: secondIncorrectSubmittion, for: sessionOne, by: user).wait()
            // Updating old submittion
            try testSessionRepository.submit(content: secondCorrectSubmittion, for: sessionOne, by: user).wait()

            let answers = try TaskSessionAnswer.query(on: conn).all().wait()
            let choises = try MultipleChoiseTaskAnswer.query(on: conn).all().wait()
            let taskAnswers = try TaskAnswer.query(on: conn).all().wait()

            let choisesIDs = Set(choises.map { $0.choiseID })
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

        let userOne = try User.create(on: conn)
        let userTwo = try User.create(on: conn)

        do {
            let test = try setupTestWithTasks()

            let sessionOneEntry = try subjectTestRepository.enter(test: test, with: enterRequest, by: userOne).wait()
            let sessionTwoEntry = try subjectTestRepository.enter(test: test, with: enterRequest, by: userTwo).wait()

            let sessionOne = try TaskSession.TestParameter.resolveParameter("\(sessionOneEntry.id)", conn: conn).wait()
            let sessionTwo = try TaskSession.TestParameter.resolveParameter("\(sessionTwoEntry.id)", conn: conn).wait()

            let firstSubmittion     = try submittionAt(index: 1, for: test)
            let secondSubmittion    = try submittionAt(index: 2, for: test)
            let thirdSubmittion     = try submittionAt(index: 3, for: test)

            try testSessionRepository.submit(content: firstSubmittion, for: sessionOne, by: userOne).wait()
            try testSessionRepository.submit(content: firstSubmittion, for: sessionTwo, by: userTwo).wait()

            try testSessionRepository.submit(content: secondSubmittion, for: sessionOne, by: userOne).wait()

            try testSessionRepository.submit(content: thirdSubmittion, for: sessionOne, by: userOne).wait()
            try testSessionRepository.submit(content: thirdSubmittion, for: sessionTwo, by: userTwo).wait()

            try testSessionRepository.submit(test: sessionOne, by: userOne).wait()

            var results = try TaskResult.DatabaseModel.query(on: conn).all().wait()

            XCTAssertEqual(results.count, 3)
            XCTAssertNotNil(sessionOneEntry.submittedAt)
            XCTAssertNil(sessionTwoEntry.submittedAt)

            try testSessionRepository.submit(test: sessionTwo, by: userTwo).wait()
            results = try TaskResult.DatabaseModel.query(on: conn).all().wait()

            XCTAssertEqual(results.count, 5)
            XCTAssertNotNil(sessionOneEntry.submittedAt)
            XCTAssertNotNil(sessionTwoEntry.submittedAt)
            XCTAssertEqual(results.filter({ $0.sessionID == sessionOneEntry.id }).count, 3)
            XCTAssertEqual(results.filter({ $0.sessionID == sessionTwoEntry.id }).count, 2)
            XCTAssert(results.allSatisfy({ $0.resultScore == 1 }), "One or more results was not recored as 100% correct")

            // Should throw when submtting an answer after submitting results
            XCTAssertThrowsError(
                try testSessionRepository.submit(content: thirdSubmittion, for: sessionTwo, by: userTwo).wait()
            )
            // Should throw when submtting the second time
            XCTAssertThrowsError(
                try testSessionRepository.submit(test: sessionOne, by: userOne).wait()
            )
        } catch {
            XCTFail(error.localizedDescription)
        }
    }

    func testResultsAfterSubmittion() throws {
        do {
            let test = try setupTestWithTasks()

            let userOne = try User.create(on: conn)
            let userTwo = try User.create(on: conn)
            let userThree = try User.create(on: conn)

            let sessionOneEntry = try subjectTestRepository.enter(test: test, with: enterRequest, by: userOne).wait()
            let sessionTwoEntry = try subjectTestRepository.enter(test: test, with: enterRequest, by: userTwo).wait()

            let sessionOne = try TaskSession.TestParameter.resolveParameter("\(sessionOneEntry.id)", conn: conn).wait()
            let sessionTwo = try TaskSession.TestParameter.resolveParameter("\(sessionTwoEntry.id)", conn: conn).wait()

            let firstSubmittion     = try submittionAt(index: 1, for: test)
            let secondSubmittion    = try submittionAt(index: 2, for: test)
            let thirdSubmittion     = try submittionAt(index: 3, for: test)

            try testSessionRepository.submit(content: firstSubmittion, for: sessionOne, by: userOne).wait()
            try testSessionRepository.submit(content: firstSubmittion, for: sessionTwo, by: userTwo).wait()

            try testSessionRepository.submit(content: secondSubmittion, for: sessionOne, by: userOne).wait()

            try testSessionRepository.submit(content: thirdSubmittion, for: sessionOne, by: userOne).wait()
            try testSessionRepository.submit(content: thirdSubmittion, for: sessionTwo, by: userTwo).wait()

            try testSessionRepository.submit(test: sessionOne, by: userOne).wait()
            try testSessionRepository.submit(test: sessionTwo, by: userTwo).wait()

            let userOneResults = try testSessionRepository.results(in: sessionOne, for: userOne).wait()
            let userTwoResults = try testSessionRepository.results(in: sessionTwo, for: userTwo).wait()

            XCTAssertThrowsError(
                try testSessionRepository.results(in: sessionOne, for: userThree).wait()
            )
            XCTAssertThrowsError(
                try testSessionRepository.results(in: sessionOne, for: userTwo).wait()
            )

            XCTAssertEqual(userOneResults.score, 3)
            XCTAssertEqual(userOneResults.scoreProsentage, 1)
            XCTAssertEqual(userOneResults.maximumScore, 3)

            XCTAssertEqual(userTwoResults.score, 2)
            XCTAssertEqual(userTwoResults.scoreProsentage, 2/3)
            XCTAssertEqual(userTwoResults.maximumScore, 3)
        } catch {
            XCTFail(error.localizedDescription)
        }
    }

    func testOverview() throws {
        do {
            let test = try setupTestWithTasks()

            let userOne = try User.create(on: conn)
            let userTwo = try User.create(on: conn)
            let userThree = try User.create(on: conn)

            let sessionOneEntry = try subjectTestRepository.enter(test: test, with: enterRequest, by: userOne).wait()
            let sessionTwoEntry = try subjectTestRepository.enter(test: test, with: enterRequest, by: userTwo).wait()

            let sessionOne = try TaskSession.TestParameter.resolveParameter("\(sessionOneEntry.id)", conn: conn).wait()
            let sessionTwo = try TaskSession.TestParameter.resolveParameter("\(sessionTwoEntry.id)", conn: conn).wait()

            let firstSubmittion     = try submittionAt(index: 1, for: test)
            let secondSubmittion    = try submittionAt(index: 2, for: test)
            let thirdSubmittion     = try submittionAt(index: 3, for: test)

            try testSessionRepository.submit(content: firstSubmittion, for: sessionOne, by: userOne).wait()
            try testSessionRepository.submit(content: firstSubmittion, for: sessionTwo, by: userTwo).wait()

            try testSessionRepository.submit(content: secondSubmittion, for: sessionOne, by: userOne).wait()

            try testSessionRepository.submit(content: thirdSubmittion, for: sessionOne, by: userOne).wait()
            try testSessionRepository.submit(content: thirdSubmittion, for: sessionTwo, by: userTwo).wait()

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
            .query(on: conn)
            .sort(\.createdAt)
            .filter(\.testID, .equal, test.id)
            .filter(\.id, .equal, index)
            .join(\MultipleChoiseTaskChoise.taskId, to: \SubjectTest.Pivot.Task.taskID)
            .decode(MultipleChoiseTaskChoise.self)
            .all()
            .wait()
    }

    func multipleChoiseAnswer(with choises: [MultipleChoiseTaskChoise.ID]) -> MultipleChoiceTask.Submit {
        .init(
            timeUsed: .seconds(20),
            choises: choises,
            taskIndex: 1
        )
    }

    func setupTestWithTasks(scheduledAt: Date = .now, duration: TimeInterval = .minutes(10), numberOfTasks: Int = 3) throws -> SubjectTest {
        let topic = try Topic.create(on: conn)
        let subtopic = try Subtopic.create(topic: topic, on: conn)
        let taskIds = try (0..<numberOfTasks).map { _ in
            try MultipleChoiceTask.create(subtopic: subtopic, on: conn).id
        }
        _ = try MultipleChoiceTask.create(subtopic: subtopic, on: conn)
        _ = try MultipleChoiceTask.create(subtopic: subtopic, on: conn)
        _ = try MultipleChoiceTask.create(subtopic: subtopic, on: conn)

        let user = try User.create(on: conn)

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
