//
//  User+testable.swift
//  AppTests
//
//  Created by Mats Mollestad on 09/11/2018.
//

import Vapor
import FluentPostgreSQL
import Crypto
@testable import KognitaCore


extension User {
    public static func create(username: String? = nil, email: String? = nil, isAdmin: Bool = true, isEmailVerified: Bool = true, on conn: PostgreSQLConnection) throws -> User {

        let createEmail = email ?? UUID().uuidString + "@email.com"
        let createUsername = username ?? UUID().uuidString
        
        let password = try BCrypt.hash("password")
        return try User(username: createUsername, email: createEmail, passwordHash: password, isAdmin: isAdmin, isEmailVerified: isEmailVerified)
            .save(on: conn)
            .wait()
    }
}
