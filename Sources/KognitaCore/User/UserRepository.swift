//
//  UserRepository.swift
//  KognitaCore
//
//  Created by Mats Mollestad on 11/04/2019.
//

import Crypto
import FluentPostgreSQL
import Vapor

public protocol UserRepository:
    CreateModelRepository,
    UpdateModelRepository,
    RetriveModelRepository
    where
    CreateData      == User.Create.Data,
    CreateResponse  == User.Response,
    UpdateData      == User.Edit.Data,
    UpdateResponse  == User.Response,
    Model           == User
{
    static func first(with email: String, on conn: DatabaseConnectable) -> EventLoopFuture<User?>
}

extension User {
    public final class DatabaseRepository {}
}

extension User.DatabaseRepository: UserRepository {

    public enum Errors: LocalizedError {
        case passwordMismatch
        case missingInput
        case misformed(field: String, reason: String)
        case unauthorized
        case existingUser(email: String)
        case invalidRecruterToken

        public var errorDescription: String? {
            switch self {
            case .missingInput: return "Sjekk at all informasjon er skrevet inn"
            case .passwordMismatch: return "Passordet må skrives likt to ganger"
            case .unauthorized: return "Sjekk at epost og passord stemmer"
            case .existingUser(let email): return "Det finnes allerede en bruker med epost: \(email)"
            case .invalidRecruterToken: return "Ugyldig rekruterings kode"
            case .misformed(let field, let reason): return "Ugylding formentert \(field), fordi det \(reason)"
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
        guard !content.username.isEmpty, !content.email.isEmpty, !content.password.isEmpty else {
            throw Errors.missingInput
        }
        let lowercasedEmail = content.email.lowercased()
        guard lowercasedEmail.allSatisfy({ !$0.isWhitespace }) else {
            throw Errors.misformed(field: "email", reason: "innholder mellomrom eller lignende tegn")
        }
        guard content.password == content.verifyPassword else {
            throw Errors.passwordMismatch
        }

        // hash user's password using BCrypt
        let hash = try BCrypt.hash(content.password)
        // save new user
        let newUser = User(
            username: content.username,
            email: content.email,
            passwordHash: hash,
            role: .user
        )

        return User.query(on: conn)
            .filter(\.email == newUser.email.lowercased())
            .first()
            .flatMap { existingUser in

                guard existingUser == nil else {
                    throw Errors.existingUser(email: newUser.email)
                }
                return newUser.save(on: conn)
                    .map { try $0.content() }
        }
    }

    public static func update(model: User, to data: User.Edit.Data, by user: User, on conn: DatabaseConnectable) throws -> EventLoopFuture<User.Response> {

        guard try model.requireID() == user.requireID() else {
            throw Abort(.forbidden)
        }
        try model.updateValues(with: data)
        return model.save(on: conn)
            .map { try $0.content() }
    }

    public static func first(with email: String, on conn: DatabaseConnectable) -> EventLoopFuture<User?> {
        User.query(on: conn)
            .filter(\.email == email)
            .first()
    }
}
