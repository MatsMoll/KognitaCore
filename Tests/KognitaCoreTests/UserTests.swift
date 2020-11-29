import XCTest
import Vapor
@testable import KognitaCore
import KognitaCoreTestable

class UserTests: VaporTestCase {

    lazy var userRepository: UserRepository = { TestableRepositories.testable(with: app).userRepository }()
    lazy var resetPasswordRepository: ResetPasswordRepositoring = { TestableRepositories.testable(with: app).userRepository }()

    func testEmailVerificationTokenOnCreate() throws {

        let createRequest = User.Create.Data(
            username: "Test",
            email: "test@ntnu.no",
            password: "p1234",
            verifyPassword: "p1234",
            acceptedTerms: .accepted
        )

        let user = try userRepository.create(from: createRequest).wait()
        XCTAssertNoThrow(
            try User.VerifyEmail.Token.DatabaseModel.query(on: app.db).filter(\.$user.$id == user.id).first().unwrap(or: Abort(.internalServerError)).wait()
        )
    }

    func testCreateUserWithInvalidEmailError() throws {

        let createRequest = User.Create.Data(
            username: "Test",
            email: "testntnu.no",
            password: "p1234",
            verifyPassword: "p1234",
            acceptedTerms: .accepted
        )

        XCTAssertThrowsError(
            try userRepository.create(from: createRequest).wait()
        )
    }

    func testCreateUserWithExistingUsername() throws {

        let createRequest = User.Create.Data(
            username: "Test",
            email: "test@ntnu.no",
            password: "p1234",
            verifyPassword: "p1234",
            acceptedTerms: .accepted
        )
        let sameUsernameRequest = User.Create.Data(
            username: createRequest.username,
            email: "test2@ntnu.no",
            password: "p1234",
            verifyPassword: "p1234",
            acceptedTerms: .accepted
        )

        XCTAssertNoThrow(
            try userRepository.create(from: createRequest).wait()
        )
        throwsError(ofType: User.DatabaseRepository.Errors.self) {
            _ = try userRepository.create(from: sameUsernameRequest).wait()
        }
    }

    func testCreateUserWithExistingEmail() throws {

        let createRequest = User.Create.Data(
            username: "Test",
            email: "test@ntnu.no",
            password: "p1234",
            verifyPassword: "p1234",
            acceptedTerms: .accepted
        )
        let sameEamilRequest = User.Create.Data(
            username: "Test 2",
            email: createRequest.email,
            password: "p1234",
            verifyPassword: "p1234",
            acceptedTerms: .accepted
        )

        XCTAssertNoThrow(
            try userRepository.create(from: createRequest).wait()
        )
        throwsError(ofType: User.DatabaseRepository.Errors.self) {
            _ = try userRepository.create(from: sameEamilRequest).wait()
        }
    }

    func testNotNTNUEmailCreateError() throws {
        let createRequestNTNU = User.Create.Data(
            username: "Test",
            email: "test@ntnu.no",
            password: "p1234",
            verifyPassword: "p1234",
            acceptedTerms: .accepted
        )
        let createRequestInvalid = User.Create.Data(
            username: "Test",
            email: "test@test.no",
            password: "p1234",
            verifyPassword: "p1234",
            acceptedTerms: .accepted
        )
        XCTAssertNoThrow(
            try userRepository.create(from: createRequestNTNU).wait()
        )
        XCTAssertThrowsError(
            try userRepository.create(from: createRequestInvalid).wait()
        )
    }

    func testResetPassword() throws {
        let user = try User.create(on: app)
        let dbUser = try User.DatabaseModel.find(user.id, on: database).unwrap(or: Errors.badTest).wait()

        let tokenResponse = try resetPasswordRepository.startReset(for: user).wait()

        let newPassword = "p1234"

        XCTAssertFalse(try app.password.verify(newPassword, created: dbUser.passwordHash))

        let resetRequest = User.ResetPassword.Data(
            password: newPassword,
            verifyPassword: newPassword
        )

        try resetPasswordRepository
            .reset(to: resetRequest, with: tokenResponse.token).wait()

        let savedUser = try User.DatabaseModel.find(user.id, on: database).unwrap(or: Errors.badTest).wait()

        XCTAssert(try app.password.verify(newPassword, created: savedUser.passwordHash))
    }

    func testResetPasswordPasswordMismatch() throws {
        let user = try User.create(on: app)

        let tokenResponse = try resetPasswordRepository.startReset(for: user).wait()

        let newPassword = "p1234"

        let resetRequest = User.ResetPassword.Data(
            password: newPassword,
            verifyPassword: "something else"
        )

        XCTAssertThrowsError(
            try resetPasswordRepository
                .reset(to: resetRequest, with: tokenResponse.token).wait()
        )
        let savedUser = try User.DatabaseModel
            .find(user.id, on: database).unwrap(or: Abort(.internalServerError)).wait()
        XCTAssertFalse(try app.password.verify(newPassword, created: savedUser.passwordHash))
    }

    func testResetPasswordExpiredToken() throws {
        let user = try User.create(on: app)

        let tokenResponse = try resetPasswordRepository.startReset(for: user).wait()
        let token = try User.ResetPassword.Token.DatabaseModel.query(on: database)
            .filter(\.$string == tokenResponse.token)
            .first()
            .unwrap(or: Abort(.badRequest))
            .wait()
        token.deletedAt = Date()
        _ = try token.save(on: database).wait()

        let newPassword = "p1234"

        let resetRequest = User.ResetPassword.Data(
            password: newPassword,
            verifyPassword: newPassword
        )

        XCTAssertThrowsError(
            try resetPasswordRepository
                .reset(to: resetRequest, with: tokenResponse.token).wait()
        )
        let savedUser = try User.DatabaseModel.find(user.id, on: database).unwrap(or: Abort(.internalServerError)).wait()
        XCTAssertFalse(try app.password.verify(newPassword, created: savedUser.passwordHash))
    }

    func testUserLoginLog() throws {
        let user = try User.create(on: app)

        try userRepository.logLogin(for: user, with: "127.0.0.1").wait()
        try userRepository.logLogin(for: user, with: nil).wait()

        let logs = try User.Login.Log.query(on: database).all().wait()

        XCTAssertEqual(logs.filter({ $0.ipAddress == "127.0.0.1" && $0.$user.id == user.id }).count, 1)
        XCTAssertEqual(logs.filter({ $0.ipAddress == nil && $0.$user.id == user.id }).count, 1)
    }

    static let allTests = [
        ("testEmailVerificationTokenOnCreate", testEmailVerificationTokenOnCreate),
        ("testCreateUserWithInvalidEmailError", testCreateUserWithInvalidEmailError),
        ("testNotNTNUEmailCreateError", testNotNTNUEmailCreateError),
        ("testResetPassword", testResetPassword),
        ("testResetPasswordPasswordMismatch", testResetPasswordPasswordMismatch),
        ("testResetPasswordExpiredToken", testResetPasswordExpiredToken)
    ]
}
