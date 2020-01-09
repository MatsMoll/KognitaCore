import Foundation
@testable import KognitaCore
import KognitaCoreTestable
import XCTest


@available(OSX 10.15, *)
class SubjectTestTests: VaporTestCase {

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
                .query(on: conn)
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
            duration: .minutes(10),
            scheduledAt: .now,
            password: "password",
            title: "Testing"
        )
        XCTAssertThrowsError(
            _ = try SubjectTest.DatabaseRepository.create(from: data, by: nil, on: conn).wait()
        )
    }

    func testCreateTestUnprivileged() throws {
        let user = try User.create(role: .user, on: conn)
        let data = SubjectTest.Create.Data(
            tasks: [],
            duration: .minutes(10),
            scheduledAt: .now,
            password: "password",
            title: "Testing"
        )
        XCTAssertThrowsError(
            _ = try SubjectTest.DatabaseRepository.create(from: data, by: user, on: conn).wait()
        )
    }

    func testOpeningTestWhenUnprivileged() throws {
        let user = try User.create(role: .user, on: conn)

        let test = try setupTestWithTasks()
        XCTAssertThrowsError(
            try SubjectTest.DatabaseRepository.open(test: test, by: user, on: conn).wait()
        )
    }

    func testEnteringTestWhenClosed() throws {

        let user = try User.create(on: conn)

        do {
            let test = try setupTestWithTasks(
                scheduledAt: Date().addingTimeInterval(.minutes(2))
            )
            XCTAssertThrowsError(
                try SubjectTest.DatabaseRepository
                    .enter(test: test, with: enterRequest, by: user, on: conn).wait()
            )
        } catch {
            XCTFail(error.localizedDescription)
        }
    }

    func testEnteringWithIncorrectPassword() throws {

        let user = try User.create(on: conn)

        do {
            let test = try setupTestWithTasks()
            XCTAssertThrowsError(
                try SubjectTest.DatabaseRepository
                    .enter(test: test, with: .init(password: "incorrect"), by: user, on: conn).wait()
            )
        } catch {
            XCTFail(error.localizedDescription)
        }
    }

    func testEnteringMultipleTimes() throws {

        let userOne = try User.create(on: conn)
        let userTwo = try User.create(on: conn)

        do {
            let test = try setupTestWithTasks()

            let sessionOneEntry = try SubjectTest.DatabaseRepository.enter(test: test, with: enterRequest, by: userOne, on: conn).wait()
            let sessionTwoEntry = try SubjectTest.DatabaseRepository.enter(test: test, with: enterRequest, by: userTwo, on: conn).wait()

            let sessionOne = try sessionOneEntry.representable(on: conn).wait()
            let sessionTwo = try sessionTwoEntry.representable(on: conn).wait()

            XCTAssertEqual(sessionOne.testID, test.id)
            XCTAssertEqual(sessionOne.userID, userOne.id)
            XCTAssertEqual(sessionTwo.testID, test.id)
            XCTAssertEqual(sessionTwo.userID, userTwo.id)

            XCTAssertThrowsError(
                _ = try SubjectTest.DatabaseRepository
                    .enter(test: test, with: enterRequest, by: userOne, on: conn).wait()
            )

            let sessions = try TestSession.query(on: conn).all().wait()
            XCTAssertEqual(sessions.count, 2)
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
        ("testCreateTest",                                  testCreateTest),
        ("testCreateTestUnauthorized",                      testCreateTestUnauthorized),
        ("testCreateTestUnprivileged",                      testCreateTestUnprivileged),
        ("testOpeningTestWhenUnprivileged",                 testOpeningTestWhenUnprivileged),
        ("testEnteringTestWhenClosed",                      testEnteringTestWhenClosed),
        ("testEnteringWithIncorrectPassword",               testEnteringWithIncorrectPassword),
        ("testEnteringMultipleTimes",                       testEnteringMultipleTimes),
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
