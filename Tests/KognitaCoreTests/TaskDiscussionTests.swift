import XCTest
@testable import KognitaCore

final class TaskDiscussionTests: VaporTestCase {

    func testCreateDiscussionNotLoggedIn() {
        do {
            _ = try Task.create(on: conn)
            _ = try Task.create(on: conn)
            let task = try Task.create(on: conn)

            let data = try TaskDiscussion.Create.Data(
                description: "test",
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
                description: "test",
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


    func testCreateDiscussionResponseWithoutDiscussion() {
        do {
            let user = try User.create(on: conn)

            let data = TaskDiscussion.Pivot.Response.Create.Data(
                response: "test",
                discussionID: -1
            )

            XCTAssertThrowsError(
                try TaskDiscussion.DatabaseRepository.respond(with: data, by: user, on: conn).wait()
            )

        } catch {
            XCTFail(error.localizedDescription)
        }
    }

    func testCreateDiscussionResponse() {
        do {
            let user = try User.create(on: conn)
            let discussion = try TaskDiscussion.create(on: conn)

            let firstDiscussionResponse = try TaskDiscussion.Pivot.Response.Create.Data(
                response: "test",
                discussionID: discussion.requireID()
            )

            let secondDiscussionResponse = try TaskDiscussion.Pivot.Response.Create.Data(
                response: "testing",
                discussionID: discussion.requireID()
            )

            _ = try TaskDiscussion.DatabaseRepository.respond(with: firstDiscussionResponse, by: user, on: conn).wait()
            _ = try TaskDiscussion.DatabaseRepository.respond(with: secondDiscussionResponse, by: user, on: conn).wait()

            let responses = try TaskDiscussion.DatabaseRepository.responses(to: discussion.requireID(), on: conn).wait()

            XCTAssertEqual(responses.count, 2)

            let firstResponse = try XCTUnwrap(responses.first)
            let secondResponse = try XCTUnwrap(responses.last)
            XCTAssertEqual(firstResponse.response, firstDiscussionResponse.response)
            XCTAssertEqual(secondResponse.response, secondDiscussionResponse.response)
            XCTAssertEqual(firstResponse.username, user.username)
            XCTAssertEqual(secondResponse.username, user.username)

        } catch {
            XCTFail(error.localizedDescription)
        }

    }

    static let allTests = [
        ("testCreateDiscussionNotLoggedIn", testCreateDiscussionNotLoggedIn),
        ("testCreateDiscussions", testCreateDiscussions)
    ]
}
