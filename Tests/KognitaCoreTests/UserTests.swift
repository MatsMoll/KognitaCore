import XCTest
import Vapor
import FluentPostgreSQL
import Crypto
@testable import KognitaCore
import KognitaCoreTestable

class UserTests: VaporTestCase {

    lazy var userRepository: some UserRepository = { User.DatabaseRepository(conn: conn) }()
    lazy var resetPasswordRepository: some ResetPasswordRepositoring = { User.ResetPassword.Token.DatabaseRepository(conn: conn) }()

    func testEmailVerificationTokenOnCreate() throws {

        let createRequest = User.Create.Data(
            username: "Test",
            email: "test@ntnu.no",
            password: "p1234",
            verifyPassword: "p1234",
            acceptedTermsInput: "on" // The same as checked
        )

        let user = try userRepository.create(from: createRequest, by: nil).wait()
        XCTAssertNoThrow(
            try User.VerifyEmail.Token.query(on: conn).filter(\.userID == user.userId).first().unwrap(or: Abort(.internalServerError)).wait()
        )
    }

    func testCreateUserWithInvalidEmailError() throws {

        let createRequest = User.Create.Data(
            username: "Test",
            email: "testntnu.no",
            password: "p1234",
            verifyPassword: "p1234",
            acceptedTermsInput: "on" // The same as checked
        )

        XCTAssertThrowsError(
            try userRepository.create(from: createRequest, by: nil).wait()
        )
    }

    func testNotNTNUEmailCreateError() throws {
        let createRequestNTNU = User.Create.Data(
            username: "Test",
            email: "test@ntnu.no",
            password: "p1234",
            verifyPassword: "p1234",
            acceptedTermsInput: "on" // The same as checked
        )
        let createRequestInvalid = User.Create.Data(
            username: "Test",
            email: "test@test.no",
            password: "p1234",
            verifyPassword: "p1234",
            acceptedTermsInput: "on" // The same as checked
        )
        XCTAssertNoThrow(
            try userRepository.create(from: createRequestNTNU, by: nil).wait()
        )
        XCTAssertThrowsError(
            try userRepository.create(from: createRequestInvalid, by: nil).wait()
        )
    }

    func testResetPassword() throws {
        let user = try User.create(on: conn)

        let tokenResponse = try resetPasswordRepository.create(from: .init(), by: user).wait()

        let newPassword = "p1234"

        XCTAssertFalse(try BCrypt.verify(newPassword, created: user.passwordHash))

        let resetRequest = User.ResetPassword.Data(
            password: newPassword,
            verifyPassword: newPassword
        )

        try resetPasswordRepository
            .reset(to: resetRequest, with: tokenResponse.token).wait()

        let savedUser = try userRepository
            .find(user.requireID(), or: Abort(.internalServerError)).wait()

        XCTAssert(try BCrypt.verify(newPassword, created: savedUser.passwordHash))
    }

    func testResetPasswordPasswordMismatch() throws {
        let user = try User.create(on: conn)

        let tokenResponse = try resetPasswordRepository.create(from: .init(), by: user).wait()

        let newPassword = "p1234"

        let resetRequest = User.ResetPassword.Data(
            password: newPassword,
            verifyPassword: "something else"
        )

        XCTAssertThrowsError(
            try resetPasswordRepository
                .reset(to: resetRequest, with: tokenResponse.token).wait()
        )
        let savedUser = try userRepository
            .find(user.requireID(), or: Abort(.internalServerError)).wait()
        XCTAssertFalse(try BCrypt.verify(newPassword, created: savedUser.passwordHash))
    }

    func testResetPasswordExpiredToken() throws {
        let user = try User.create(on: conn)

        let tokenResponse = try resetPasswordRepository.create(from: .init(), by: user).wait()
        var token = try User.ResetPassword.Token.query(on: conn)
            .filter(\.string == tokenResponse.token)
            .first()
            .unwrap(or: Abort(.badRequest))
            .wait()
        token.deletedAt = Date()
        _ = try token.save(on: conn).wait()

        let newPassword = "p1234"

        let resetRequest = User.ResetPassword.Data(
            password: newPassword,
            verifyPassword: newPassword
        )

        XCTAssertThrowsError(
            try resetPasswordRepository
                .reset(to: resetRequest, with: tokenResponse.token).wait()
        )
        let savedUser = try userRepository
            .find(user.requireID(), or: Abort(.internalServerError)).wait()
        XCTAssertFalse(try BCrypt.verify(newPassword, created: savedUser.passwordHash))
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
