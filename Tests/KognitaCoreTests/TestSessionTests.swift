import Foundation
@testable import KognitaCore
import KognitaCoreTestable
import XCTest


@available(OSX 10.15, *)
class TestSessionTests: VaporTestCase {

    func testSubmittingAndUpdatingAnswerMultipleUsers() throws {

        let userOne = try User.create(on: conn)
        let userTwo = try User.create(on: conn)

        do {
            let test = try setupTestWithTasks()

            let sessionOneEntry = try SubjectTest.DatabaseRepository.enter(test: test, with: enterRequest, by: userOne, on: conn).wait()
            let sessionTwoEntry = try SubjectTest.DatabaseRepository.enter(test: test, with: enterRequest, by: userTwo, on: conn).wait()

            let sessionOne = try sessionOneEntry.representable(on: conn).wait()
            let sessionTwo = try sessionTwoEntry.representable(on: conn).wait()

            try XCTAssertNotEqual(sessionOne.requireID(), sessionTwo.requireID())
            XCTAssertEqual(sessionOne.testID, test.id)
            XCTAssertEqual(sessionOne.userID, userOne.id)
            XCTAssertEqual(sessionTwo.testID, test.id)
            XCTAssertEqual(sessionTwo.userID, userTwo.id)

            let firstSubmit                 = try submittionAt(index: 1, for: test)
            var secondIncorrectSubmittion   = try submittionAt(index: 2, for: test, isCorrect: false)
            let secondCorrectSubmittion     = try submittionAt(index: 2, for: test, isCorrect: true)
            var thiredSubmit                = try submittionAt(index: 3, for: test)

            try TestSession.DatabaseRepository.submit(content: firstSubmit, for: sessionOne, by: userOne, on: conn).wait()
            try TestSession.DatabaseRepository.submit(content: firstSubmit, for: sessionTwo, by: userTwo, on: conn).wait()
            try TestSession.DatabaseRepository.submit(content: secondIncorrectSubmittion, for: sessionOne, by: userOne, on: conn).wait()


            // Submitting a choise to a task that do not contain the choise
            secondIncorrectSubmittion.taskIndex = 1
            XCTAssertThrowsError(
                try TestSession.DatabaseRepository.submit(content: secondIncorrectSubmittion, for: sessionOne, by: userOne, on: conn).wait()
            )
            // Submitting to a session that is not the user's
            XCTAssertThrowsError(
                try TestSession.DatabaseRepository.submit(content: secondCorrectSubmittion, for: sessionOne, by: userTwo, on: conn).wait()
            )
            // Updating old submittion
            try TestSession.DatabaseRepository.submit(content: secondCorrectSubmittion, for: sessionOne, by: userOne, on: conn).wait()

            try TestSession.DatabaseRepository.submit(content: thiredSubmit, for: sessionOne, by: userOne, on: conn).wait()
            try TestSession.DatabaseRepository.submit(content: thiredSubmit, for: sessionTwo, by: userTwo, on: conn).wait()

            thiredSubmit.taskIndex = 4
            XCTAssertThrowsError(
                try TestSession.DatabaseRepository
                    .submit(content: thiredSubmit, for: sessionOne, by: userOne, on: conn).wait()
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

            let sessionOneEntry = try SubjectTest.DatabaseRepository.enter(test: test, with: enterRequest, by: user, on: conn).wait()
            let sessionOne = try sessionOneEntry.representable(on: conn).wait()

            let firstSubmittion             = try submittionAt(index: 1, for: test)
            let secondIncorrectSubmittion   = try submittionAt(index: 2, for: test, isCorrect: false)
            let secondCorrectSubmittion     = try submittionAt(index: 2, for: test, isCorrect: true)

            try TestSession.DatabaseRepository.submit(content: firstSubmittion, for: sessionOne, by: user, on: conn).wait()
            try TestSession.DatabaseRepository.submit(content: secondIncorrectSubmittion, for: sessionOne, by: user, on: conn).wait()
            // Updating old submittion
            try TestSession.DatabaseRepository.submit(content: secondCorrectSubmittion, for: sessionOne, by: user, on: conn).wait()

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

            let sessionOneEntry = try SubjectTest.DatabaseRepository.enter(test: test, with: enterRequest, by: userOne, on: conn).wait()
            let sessionTwoEntry = try SubjectTest.DatabaseRepository.enter(test: test, with: enterRequest, by: userTwo, on: conn).wait()

            let sessionOne = try sessionOneEntry.representable(on: conn).wait()
            let sessionTwo = try sessionTwoEntry.representable(on: conn).wait()

            let firstSubmittion     = try submittionAt(index: 1, for: test)
            let secondSubmittion    = try submittionAt(index: 2, for: test)
            let thirdSubmittion     = try submittionAt(index: 3, for: test)

            try TestSession.DatabaseRepository.submit(content: firstSubmittion, for: sessionOne, by: userOne, on: conn).wait()
            try TestSession.DatabaseRepository.submit(content: firstSubmittion, for: sessionTwo, by: userTwo, on: conn).wait()

            try TestSession.DatabaseRepository.submit(content: secondSubmittion, for: sessionOne, by: userOne, on: conn).wait()

            try TestSession.DatabaseRepository.submit(content: thirdSubmittion, for: sessionOne, by: userOne, on: conn).wait()
            try TestSession.DatabaseRepository.submit(content: thirdSubmittion, for: sessionTwo, by: userTwo, on: conn).wait()

            try TestSession.DatabaseRepository.submit(test: sessionOneEntry, by: userOne, on: conn).wait()

            var results = try TaskResult.query(on: conn).all().wait()

            XCTAssertEqual(results.count, 3)
            XCTAssertNotNil(sessionOneEntry.submittedAt)
            XCTAssertNil(sessionTwoEntry.submittedAt)

            try TestSession.DatabaseRepository.submit(test: sessionTwoEntry, by: userTwo, on: conn).wait()
            results = try TaskResult.query(on: conn).all().wait()

            XCTAssertEqual(results.count, 5)
            XCTAssertNotNil(sessionOneEntry.submittedAt)
            XCTAssertNotNil(sessionTwoEntry.submittedAt)
            XCTAssertEqual(results.filter({ $0.sessionID == sessionOneEntry.id }).count, 3)
            XCTAssertEqual(results.filter({ $0.sessionID == sessionTwoEntry.id }).count, 2)
            XCTAssert(results.allSatisfy({ $0.resultScore == 1 }), "One or more results was not recored as 100% correct")

            // Should throw when submtting an answer after submitting results
            XCTAssertThrowsError(
                try TestSession.DatabaseRepository.submit(content: thirdSubmittion, for: sessionTwo, by: userTwo, on: conn).wait()
            )
            // Should throw when submtting the second time
            XCTAssertThrowsError(
                try TestSession.DatabaseRepository.submit(test: sessionOneEntry, by: userOne, on: conn).wait()
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

            let sessionOneEntry = try SubjectTest.DatabaseRepository.enter(test: test, with: enterRequest, by: userOne, on: conn).wait()
            let sessionTwoEntry = try SubjectTest.DatabaseRepository.enter(test: test, with: enterRequest, by: userTwo, on: conn).wait()

            let sessionOne = try sessionOneEntry.representable(on: conn).wait()
            let sessionTwo = try sessionTwoEntry.representable(on: conn).wait()

            let firstSubmittion     = try submittionAt(index: 1, for: test)
            let secondSubmittion    = try submittionAt(index: 2, for: test)
            let thirdSubmittion     = try submittionAt(index: 3, for: test)

            try TestSession.DatabaseRepository.submit(content: firstSubmittion, for: sessionOne, by: userOne, on: conn).wait()
            try TestSession.DatabaseRepository.submit(content: firstSubmittion, for: sessionTwo, by: userTwo, on: conn).wait()

            try TestSession.DatabaseRepository.submit(content: secondSubmittion, for: sessionOne, by: userOne, on: conn).wait()

            try TestSession.DatabaseRepository.submit(content: thirdSubmittion, for: sessionOne, by: userOne, on: conn).wait()
            try TestSession.DatabaseRepository.submit(content: thirdSubmittion, for: sessionTwo, by: userTwo, on: conn).wait()

            try TestSession.DatabaseRepository.submit(test: sessionOneEntry, by: userOne, on: conn).wait()
            try TestSession.DatabaseRepository.submit(test: sessionTwoEntry, by: userTwo, on: conn).wait()


            let userOneResults = try TestSession.DatabaseRepository.results(in: test, for: userOne, on: conn).wait()
            let userTwoResults = try TestSession.DatabaseRepository.results(in: test, for: userTwo, on: conn).wait()

            XCTAssertThrowsError(
                try TestSession.DatabaseRepository.results(in: test, for: userThree, on: conn).wait()
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



    func submittionAt(index: Int, for test: SubjectTest, isCorrect: Bool = true) throws -> MultipleChoiseTask.Submit {
        let choises = try choisesAt(index: index, for: test)
        return try MultipleChoiseTask.Submit(
            timeUsed: .seconds(20),
            choises: choises.filter { $0.isCorrect == isCorrect }.map { try $0.requireID() },
            taskIndex: index
        )
    }

    func choisesAt(index: Int, for test: SubjectTest) throws -> [MultipleChoiseTaskChoise] {
        try SubjectTest.Pivot.Task
            .query(on: conn)
            .sort(\.createdAt)
            .filter(\.testID, .equal, test.requireID())
            .filter(\.id, .equal, index)
            .join(\MultipleChoiseTaskChoise.taskId, to: \SubjectTest.Pivot.Task.taskID)
            .decode(MultipleChoiseTaskChoise.self)
            .all()
            .wait()
    }

    func multipleChoiseAnswer(with choises: [MultipleChoiseTaskChoise.ID]) -> MultipleChoiseTask.Submit {
        .init(
            timeUsed: .seconds(20),
            choises: choises,
            taskIndex: 1
        )
    }

    func setupTestWithTasks(scheduledAt: Date = .now, duration: TimeInterval = .minutes(10), numberOfTasks: Int = 3) throws -> SubjectTest {
        let subtopic = try Subtopic.create(on: conn)
        let taskIds = try (0..<numberOfTasks).map { _ in
            try MultipleChoiseTask.create(subtopic: subtopic, on: conn)
                .requireID()
        }
        _ = try MultipleChoiseTask.create(subtopic: subtopic, on: conn)
        _ = try MultipleChoiseTask.create(subtopic: subtopic, on: conn)
        _ = try MultipleChoiseTask.create(subtopic: subtopic, on: conn)

        let user = try User.create(on: conn)

        let data = SubjectTest.Create.Data(
            tasks:          taskIds,
            duration:       duration,
            scheduledAt:    scheduledAt,
            password:       "password",
            title:          "Testing"
        )

        if scheduledAt.timeIntervalSinceNow < 0 {
            let test = try SubjectTest.DatabaseRepository.create(from: data, by: user, on: conn).wait()
            return try SubjectTest.DatabaseRepository.open(test: test, by: user, on: conn).wait()
        } else {
            return try SubjectTest.DatabaseRepository.create(from: data, by: user, on: conn).wait()
        }
    }

    var enterRequest: SubjectTest.Enter.Request {
        .init(password: "password")
    }

    static let allTests = [
        ("testUpdateAnswerInSession",                       testUpdateAnswerInSession),
        ("testSubmittingAndUpdatingAnswerMultipleUsers",    testSubmittingAndUpdatingAnswerMultipleUsers),
        ("testSubmittingTestSession",                       testSubmittingTestSession),
        ("testResultsAfterSubmittion",                      testResultsAfterSubmittion)
    ]
}
