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
    public static func create(username: String = "Mats", email: String? = nil, role: Role = .creator, canPractice: Bool = true, on conn: PostgreSQLConnection) throws -> User {
        
        let createEmail = email ?? UUID().uuidString + "@email.com"
        
        let password = try BCrypt.hash("password")
        let user = User(username: username, email: createEmail, passwordHash: password, role: role, canPractice: canPractice)
        return try user.save(on: conn).wait()
    }
}
