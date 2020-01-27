import XCTest
import Vapor
import FluentPostgreSQL
import Crypto
@testable import KognitaCore
import KognitaCoreTestable

class UserTests: VaporTestCase {

    func testEmailVerificationTokenOnCreate() throws {

        let createRequest = User.Create.Data(
            username: "Test",
            email: "test@ntnu.no",
            password: "p1234",
            verifyPassword: "p1234",
            acceptedTermsInput: "on" // The same as checked
        )

        let user = try User.DatabaseRepository.create(from: createRequest, by: nil, on: conn).wait()
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
            try User.DatabaseRepository.create(from: createRequest, by: nil, on: conn).wait()
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
            try User.DatabaseRepository.create(from: createRequestNTNU, by: nil, on: conn).wait()
        )
        XCTAssertThrowsError(
            try User.DatabaseRepository.create(from: createRequestInvalid, by: nil, on: conn).wait()
        )
    }

    func testResetPassword() throws {
        let user = try User.create(on: conn)
        
        let tokenResponse = try User.ResetPassword.Token.Repository
            .create(by: user, on: conn).wait()
        
        let newPassword = "p1234"
        
        XCTAssertFalse(try BCrypt.verify(newPassword, created: user.passwordHash))
        
        let resetRequest = User.ResetPassword.Data(
            password:       newPassword,
            verifyPassword: newPassword
        )
        
        try User.ResetPassword.Token.Repository
            .reset(to: resetRequest, with: tokenResponse.token, on: conn).wait()
        
        let savedUser = try User.DatabaseRepository
            .find(user.requireID(), or: Abort(.internalServerError), on: conn).wait()
        
        XCTAssert(try BCrypt.verify(newPassword, created: savedUser.passwordHash))
    }
    
    func testResetPasswordPasswordMismatch() throws {
        let user = try User.create(on: conn)
        
        let tokenResponse = try User.ResetPassword.Token.Repository
            .create(by: user, on: conn).wait()
        
        let newPassword = "p1234"
        
        let resetRequest = User.ResetPassword.Data(
            password:       newPassword,
            verifyPassword: "something else"
        )
        
        XCTAssertThrowsError(
            try User.ResetPassword.Token.Repository
                .reset(to: resetRequest, with: tokenResponse.token, on: conn).wait()
        )
        let savedUser = try User.DatabaseRepository
            .find(user.requireID(), or: Abort(.internalServerError), on: conn).wait()
        XCTAssertFalse(try BCrypt.verify(newPassword, created: savedUser.passwordHash))
    }
    
    func testResetPasswordExpiredToken() throws {
        let user = try User.create(on: conn)
        
        let tokenResponse = try User.ResetPassword.Token.Repository
            .create(by: user, on: conn).wait()
        var token = try User.ResetPassword.Token.Repository
            .first(where: \.string == tokenResponse.token, or: Abort(.internalServerError), on: conn).wait()
        token.deletedAt = Date()
        _ = try token.save(on: conn).wait()
        
        let newPassword = "p1234"
        
        let resetRequest = User.ResetPassword.Data(
            password:       newPassword,
            verifyPassword: newPassword
        )
        
        XCTAssertThrowsError(
            try User.ResetPassword.Token.Repository
                .reset(to: resetRequest, with: tokenResponse.token, on: conn).wait()
        )
        let savedUser = try User.DatabaseRepository
            .find(user.requireID(), or: Abort(.internalServerError), on: conn).wait()
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
