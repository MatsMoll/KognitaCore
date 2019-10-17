//
//  UserRepository.swift
//  KognitaCore
//
//  Created by Mats Mollestad on 11/04/2019.
//

import Crypto
import FluentPostgreSQL
import Vapor

extension User {
    public final class Repository : KognitaRepository, KognitaRepositoryEditable, KognitaRepositoryDeletable {
        public typealias Model = User
    }
}

extension User.Repository {

    public enum Errors: LocalizedError {
        case passwordMismatch
        case missingInput
        case unauthorized
        case existingUser(String)
        case invalidRecruterToken

        public var errorDescription: String? {
            switch self {
            case .missingInput: return "Sjekk at all informasjon er skrevet inn"
            case .passwordMismatch: return "Passordet må skrives likt to ganger"
            case .unauthorized: return "Sjekk at epost og passord stemmer"
            case .existingUser(let email): return "Det finnes allerede en bruker med epost: \(email)"
            case .invalidRecruterToken: return "Ugyldig rekruterings kode"
            }
        }
    }

    static public func login(with user: User, conn: DatabaseConnectable) throws -> Future<UserToken> {
        // create new token for this user
        let token = try UserToken.create(userID: user.requireID())

        // save and return token
        return token.save(on: conn)
    }

    static public func create(from content: User.Create.Data, by user: User?, on conn: DatabaseConnectable) throws -> EventLoopFuture<User.Response> {
        
        guard content.acceptedTerms else {
            throw Errors.missingInput
        }
        guard !content.name.isEmpty, !content.email.isEmpty, !content.password.isEmpty else {
            throw Errors.missingInput
        }
        guard content.password == content.verifyPassword else {
            throw Errors.passwordMismatch
        }

        // hash user's password using BCrypt
        let hash = try BCrypt.hash(content.password)
        // save new user
        let newUser = User(
            name: content.name,
            email: content.email,
            passwordHash: hash,
            role: .user
        )

        return User.query(on: conn)
            .filter(\.email == newUser.email)
            .first()
            .flatMap { existingUser in

                guard existingUser == nil else {
                    throw Errors.existingUser(newUser.email)
                }
                return newUser.save(on: conn)
                    .map { try $0.content() }
        }
    }
    
    static public func edit(_ model: User, to content: User.Edit.Data, by user: User, on conn: DatabaseConnectable) throws -> EventLoopFuture<User.Response> {
        guard try model.requireID() == user.requireID() else {
            throw Abort(.forbidden)
        }
        try model.updateValues(with: content)
        return model.save(on: conn)
            .map { try $0.content() }
    }

    static public func getAll(on conn: DatabaseConnectable) -> Future<[User.Response]> {

        return User.query(on: conn)
            .all()
            .map { users in
                try users.map { try $0.content() }
        }
    }
}
