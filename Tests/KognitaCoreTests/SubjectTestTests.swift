import Foundation
@testable import KognitaCore
import KognitaCoreTestable
import XCTest


@available(OSX 10.15, *)
class SubjectTestTests: VaporTestCase {

    func testCreateTest() throws {

        let firstTask = try Task.create(on: conn)
        let secondTask = try Task.create(on: conn)
        let thiredTask = try Task.create(on: conn)
        _ = try Task.create(on: conn)
        _ = try Task.create(on: conn)
        _ = try Task.create(on: conn)

        let user = try User.create(on: conn)
        let data = try SubjectTest.Create.Data(
            tasks: [
                firstTask.requireID(),
                secondTask.requireID(),
                thiredTask.requireID()
            ],
            duration: .minutes(10),
            opensAt: .now
        )

        do {
            let test = try SubjectTest.DatabaseRepository.create(from: data, by: user, on: conn).wait()
            let testTasks = try SubjectTest.Pivot.Task
                .query(on: conn)
                .all()
                .wait()

            XCTAssertEqual(test.opensAt, data.opensAt)
            XCTAssertEqual(test.endedAt, data.opensAt.addingTimeInterval(data.duration))
            XCTAssertEqual(testTasks.count, data.tasks.count)
        } catch {
            XCTFail(error.localizedDescription)
        }
    }

    func testCreateTestUnauthorized() {
        let data = SubjectTest.Create.Data(
            tasks: [],
            duration: .minutes(10),
            opensAt: .now
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
            opensAt: .now
        )
        XCTAssertThrowsError(
            _ = try SubjectTest.DatabaseRepository.create(from: data, by: user, on: conn).wait()
        )
    }

    func testStartingTestWhenClosed() throws {
        let firstTask = try Task.create(on: conn)
        let secondTask = try Task.create(on: conn)
        let thiredTask = try Task.create(on: conn)
        _ = try Task.create(on: conn)
        _ = try Task.create(on: conn)
        _ = try Task.create(on: conn)

        let user = try User.create(on: conn)
        let data = try SubjectTest.Create.Data(
            tasks: [
                firstTask.requireID(),
                secondTask.requireID(),
                thiredTask.requireID()
            ],
            duration: .minutes(10),
            opensAt: Date().addingTimeInterval(.minutes(20))
        )

        do {
            let test = try SubjectTest.DatabaseRepository
                .create(from: data, by: user, on: conn).wait()

            XCTAssertThrowsError(
                try SubjectTest.DatabaseRepository
                    .enter(test: test, by: user, on: conn).wait()
            )
        } catch {
            XCTFail(error.localizedDescription)
        }
    }

    func testSubmittingAndUpdatingAnswer() throws {

        let firstTask = try FlashCardTask.create(on: conn)
        let secondTask = try FlashCardTask.create(on: conn)
        let thiredTask = try FlashCardTask.create(on: conn)
        _ = try FlashCardTask.create(on: conn)
        _ = try FlashCardTask.create(on: conn)
        _ = try FlashCardTask.create(on: conn)

        let user = try User.create(on: conn)
        let data = try SubjectTest.Create.Data(
            tasks: [
                firstTask.requireID(),
                secondTask.requireID(),
                thiredTask.requireID()
            ],
            duration: .minutes(10),
            opensAt: .now
        )
        var taskAnswer = FlashCardTask.Submit(
            timeUsed: .seconds(20),
            knowledge: 0,
            taskIndex: 1,
            answer: "Some answer"
        )
        let otherAnswer = FlashCardTask.Submit(
            timeUsed: .seconds(20),
            knowledge: 0,
            taskIndex: 2,
            answer: "Other"
        )

        do {
            let test = try SubjectTest.DatabaseRepository
                .create(from: data, by: user, on: conn).wait()

            let session = try SubjectTest.DatabaseRepository
                .enter(test: test, by: user, on: conn).wait()

            XCTAssertEqual(session.testID, test.id)

            try TestSession.DatabaseRepository
                .submit(content: taskAnswer, for: session, by: user, on: conn).wait()

            taskAnswer.taskIndex = 2
            try TestSession.DatabaseRepository
                .submit(content: taskAnswer, for: session, by: user, on: conn).wait()

            try TestSession.DatabaseRepository
                .submit(content: otherAnswer, for: session, by: user, on: conn).wait()

            taskAnswer.taskIndex = 3
            try TestSession.DatabaseRepository
                .submit(content: taskAnswer, for: session, by: user, on: conn).wait()

            taskAnswer.taskIndex = 4
            XCTAssertThrowsError(
                try TestSession.DatabaseRepository
                    .submit(content: taskAnswer, for: session, by: user, on: conn).wait()
            )

            let answers = try SubjectTestAnswer.query(on: conn).all().wait()
            let flashAnswers = try FlashCardAnswer.query(on: conn).all().wait()
            let taskIDs = Set(flashAnswers.map { $0.taskID })

            XCTAssert(try answers.allSatisfy({ try $0.testID == test.requireID() }))
            XCTAssertEqual(answers.count, 3)
            XCTAssertEqual(flashAnswers.count, 3)
            XCTAssertEqual(taskIDs.count, 3)
        } catch {
            XCTFail(error.localizedDescription)
        }
    }

    static let allTests = [
        ("testCreateTest", testCreateTest),
        ("testCreateTestUnauthorized", testCreateTestUnauthorized),
        ("testCreateTestUnprivileged", testCreateTestUnprivileged),
        ("testSubmittingAndUpdatingAnswer", testSubmittingAndUpdatingAnswer)
    ]
}

extension Date {
    static var now: Date { Date() }
}

extension TimeInterval {

    static func minutes(_ time: Int) -> Double {
        Double(time) * 60
    }

    static func seconds(_ time: Int) -> Double {
        Double(time)
    }
}
