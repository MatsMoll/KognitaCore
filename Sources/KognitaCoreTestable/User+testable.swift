//
//  User+testable.swift
//  AppTests
//
//  Created by Mats Mollestad on 09/11/2018.
//

import Vapor
import FluentKit
import Crypto
@testable import KognitaCore

extension User {
    public static func create(username: String? = nil, email: String? = nil, isAdmin: Bool = true, isEmailVerified: Bool = true, on app: Application) throws -> User {

        let createEmail = email ?? UUID().uuidString + "@email.com"
        let createUsername = username ?? UUID().uuidString

        let password = try app.password.hash("password")
        let user = User.DatabaseModel(username: createUsername, email: createEmail, passwordHash: password, isAdmin: isAdmin, isEmailVerified: isEmailVerified)

        return try user.save(on: app.db)
            .flatMapThrowing { try user.content() }
            .wait()
    }
}
