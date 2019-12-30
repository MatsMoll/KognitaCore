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
            let test = try SubjectTest.Repository.create(from: data, by: user, on: conn).wait()
            let testTasks = try SubjectTest.Pivot.Task
                .query(on: conn)
//                .filter(\.testID == test.id)
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
            _ = try SubjectTest.Repository.create(from: data, by: nil, on: conn).wait()
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
            _ = try SubjectTest.Repository.create(from: data, by: user, on: conn).wait()
        )
    }

    static let allTests = [
        ("testCreateTest", testCreateTest),
        ("testCreateTest", testCreateTestUnauthorized),
        ("testCreateTest", testCreateTestUnprivileged),
    ]
}

extension Date {
    static var now: Date { Date() }
}

extension TimeInterval {
    static func minutes(_ min: Int) -> Double {
        Double(min) * 60
    }
}
