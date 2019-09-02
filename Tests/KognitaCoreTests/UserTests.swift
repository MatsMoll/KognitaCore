import XCTest
import Vapor
import FluentPostgreSQL
import Crypto
@testable import KognitaCore

class UserTests: VaporTestCase {

    func testResetPassword() throws {
        let user = try User.create(on: conn)
        
        let tokenResponse = try User.ResetPassword.Token.repository
            .create(by: user, on: conn).wait()
        
        let newPassword = "p1234"
        
        XCTAssertFalse(try BCrypt.verify(newPassword, created: user.passwordHash))
        
        let resetRequest = User.ResetPassword.Data(
            password:       newPassword,
            verifyPassword: newPassword
        )
        
        try User.ResetPassword.Token.repository
            .reset(to: resetRequest, with: tokenResponse.token, by: user, on: conn).wait()
        
        let savedUser = try User.repository
            .find(user.requireID(), or: Abort(.internalServerError), on: conn).wait()
        
        XCTAssert(try BCrypt.verify(newPassword, created: savedUser.passwordHash))
    }
    
    func testResetPasswordPasswordMismatch() throws {
        let user = try User.create(on: conn)
        
        let tokenResponse = try User.ResetPassword.Token.repository
            .create(by: user, on: conn).wait()
        
        let newPassword = "p1234"
        
        let resetRequest = User.ResetPassword.Data(
            password:       newPassword,
            verifyPassword: "something else"
        )
        
        XCTAssertThrowsError(
            try User.ResetPassword.Token.repository
                .reset(to: resetRequest, with: tokenResponse.token, by: user, on: conn).wait()
        )
        let savedUser = try User.repository
            .find(user.requireID(), or: Abort(.internalServerError), on: conn).wait()
        XCTAssertFalse(try BCrypt.verify(newPassword, created: savedUser.passwordHash))
    }
    
    func testResetPasswordUserMismatch() throws {
        let user = try User.create(on: conn)
        let otherUser = try User.create(on: conn)
        
        let tokenResponse = try User.ResetPassword.Token.repository
            .create(by: user, on: conn).wait()
        
        let newPassword = "p1234"
        
        let resetRequest = User.ResetPassword.Data(
            password:       newPassword,
            verifyPassword: newPassword
        )
        
        XCTAssertThrowsError(
            try User.ResetPassword.Token.repository
                .reset(to: resetRequest, with: tokenResponse.token, by: otherUser, on: conn).wait()
        )
        let savedUser = try User.repository
            .find(user.requireID(), or: Abort(.internalServerError), on: conn).wait()
        XCTAssertFalse(try BCrypt.verify(newPassword, created: savedUser.passwordHash))
    }
    
    func testResetPasswordExpiredToken() throws {
        let user = try User.create(on: conn)
        
        let tokenResponse = try User.ResetPassword.Token.repository
            .create(by: user, on: conn).wait()
        var token = try User.ResetPassword.Token.repository
            .first(where: \.string == tokenResponse.token, or: Abort(.internalServerError), on: conn).wait()
        token.deletedAt = Date()
        _ = try token.save(on: conn).wait()
        
        let newPassword = "p1234"
        
        let resetRequest = User.ResetPassword.Data(
            password:       newPassword,
            verifyPassword: newPassword
        )
        
        XCTAssertThrowsError(
            try User.ResetPassword.Token.repository
                .reset(to: resetRequest, with: tokenResponse.token, by: user, on: conn).wait()
        )
        let savedUser = try User.repository
            .find(user.requireID(), or: Abort(.internalServerError), on: conn).wait()
        XCTAssertFalse(try BCrypt.verify(newPassword, created: savedUser.passwordHash))
    }
    
    static let allTests = [
        ("testResetPassword", testResetPassword),
        ("testResetPasswordPasswordMismatch", testResetPasswordPasswordMismatch),
        ("testResetPasswordUserMismatch", testResetPasswordUserMismatch),
        ("testResetPasswordExpiredToken", testResetPasswordExpiredToken)
    ]
}
