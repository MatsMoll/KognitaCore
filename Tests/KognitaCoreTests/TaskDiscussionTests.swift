import XCTest
@testable import KognitaCore
import KognitaCoreTestable

final class TaskDiscussionTests: VaporTestCase {

    lazy var taskDiscussionRepository: TaskDiscussionRepositoring = { TestableRepositories.testable(with: conn).taskDiscussionRepository }()

    func testCreateDiscussionNotLoggedIn() {
        do {
            _ = try Task.create(on: conn)
            _ = try Task.create(on: conn)
            let task = try Task.create(on: conn)

            let data = try TaskDiscussion.Create.Data(
                description: "test",
                taskID: task.requireID()
            )

            XCTAssertThrowsError(try taskDiscussionRepository.create(from: data, by: nil).wait())

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

            _ = try taskDiscussionRepository.create(from: data, by: user).wait()

            let discussions = try taskDiscussionRepository.getDiscussions(in: data.taskID).wait()

            XCTAssertEqual(discussions.count, 1)

            let firstDiscussion = try XCTUnwrap(discussions.first)
            XCTAssertEqual(firstDiscussion.description, data.description)
            XCTAssertEqual(firstDiscussion.username, user.username)

        } catch {
            XCTFail(error.localizedDescription)
        }
    }

    func testCreateDiscussionNoDescription() {
        do {
            let task = try Task.create(on: conn)
            let user = try User.create(on: conn)

            let noDescriptionData = try TaskDiscussion.Create.Data(
                description: "",
                taskID: task.requireID()
            )

            let insufficientData = try TaskDiscussion.Create.Data(
                description: "tre",
                taskID: task.requireID()
            )

            XCTAssertThrowsError(try taskDiscussionRepository.create(from: insufficientData, by: user))
            XCTAssertThrowsError(try taskDiscussionRepository.create(from: noDescriptionData, by: user))

        } catch {
            XCTFail(error.localizedDescription)
        }
    }

    func testCreateDiscussionResponseWithoutDescription() {
        do {
            let user = try User.create(on: conn)

            let data = TaskDiscussionResponse.Create.Data(
                response: "test",
                discussionID: -1
            )

            XCTAssertThrowsError(
                try taskDiscussionRepository.respond(with: data, by: user).wait()
            )

        } catch {
            XCTFail(error.localizedDescription)
        }
    }

    func testCreateDiscussionResponse() {
        do {
            let user = try User.create(on: conn)
            let discussion = try TaskDiscussion.create(on: conn)

            let firstDiscussionResponse = try TaskDiscussionResponse.Create.Data(
                response: "test",
                discussionID: discussion.requireID()
            )

            let secondDiscussionResponse = try TaskDiscussionResponse.Create.Data(
                response: "testing",
                discussionID: discussion.requireID()
            )

            _ = try taskDiscussionRepository.respond(with: firstDiscussionResponse, by: user).wait()
            _ = try taskDiscussionRepository.respond(with: secondDiscussionResponse, by: user).wait()

            let responses = try taskDiscussionRepository.responses(to: discussion.requireID(), for: user).wait()

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

    func testResponseWithoutDescription() {
        do {

            let discussion = try TaskDiscussion.create(on: conn)
            let user = try User.create(on: conn)

            let noResponse = try TaskDiscussionResponse.Create.Data(
                response: "",
                discussionID: discussion.requireID()
            )

            let insufficientData = try TaskDiscussionResponse.Create.Data(
                response: "tre",
                discussionID: discussion.requireID()
            )

            XCTAssertThrowsError(try taskDiscussionRepository.respond(with: insufficientData, by: user))
            XCTAssertThrowsError(try taskDiscussionRepository.respond(with: noResponse, by: user))

        } catch {
            XCTFail(error.localizedDescription)
        }

    }

    static let allTests = [
        ("testCreateDiscussionNotLoggedIn", testCreateDiscussionNotLoggedIn),
        ("testCreateDiscussions", testCreateDiscussions),
        ("testCreateDiscussionResponseWithoutDescription", testCreateDiscussionResponseWithoutDescription),
        ("testCreateDiscussionResponse", testCreateDiscussionResponse),
        ("testCreateDiscussionNoDescription", testCreateDiscussionNoDescription),
        ("testResponseWithoutDescription", testResponseWithoutDescription)
    ]
}
