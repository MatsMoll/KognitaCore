import XCTest
@testable import KognitaCore

final class TaskDiscussionTests: VaporTestCase {

    func testCreateDiscussionNotLoggedIn() {
        do {
            _ = try Task.create(on: conn)
            _ = try Task.create(on: conn)
            let task = try Task.create(on: conn)

            let data = try TaskDiscussion.Create.Data(
                description: "LOL",
                taskID: task.requireID()
            )

            XCTAssertThrowsError(try TaskDiscussion.DatabaseRepository.create(from: data, by: nil, on: conn).wait())

        } catch {
            XCTFail(error.localizedDescription)
        }
    }

    func testCreateDiscussions() {
        do {
            _ = try Task.create(on: conn)
            _ = try Task.create(on: conn)
            let task = try Task.create(on: conn)
            let user = try User.create(on: conn)

            let data = try TaskDiscussion.Create.Data(
                description: "LOL",
                taskID: task.requireID()
            )

            _ = try TaskDiscussion.DatabaseRepository.create(from: data, by: user, on: conn).wait()

            let discussions = try TaskDiscussion.DatabaseRepository.getDiscussions(in: data.taskID, on: conn).wait()

            XCTAssertEqual(discussions.count, 1)

            let firstDiscussion = try XCTUnwrap(discussions.first)
            XCTAssertEqual(firstDiscussion.description, data.description)
            XCTAssertEqual(firstDiscussion.username, user.username)

        } catch {
            XCTFail(error.localizedDescription)
        }
    }

    static let allTests = [
        ("testCreateDiscussionNotLoggedIn", testCreateDiscussionNotLoggedIn),
        ("testCreateDiscussions", testCreateDiscussions)
    ]
}
