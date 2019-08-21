//
//  UserRepository.swift
//  KognitaCore
//
//  Created by Mats Mollestad on 11/04/2019.
//

import Crypto
import FluentPostgreSQL
import Vapor

public class UserRepository {

    public static let shared = UserRepository()

    public enum UserErrors: LocalizedError {
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

    public func login(with user: User, conn: DatabaseConnectable) throws -> Future<UserToken> {
        // create new token for this user
        let token = try UserToken.create(userID: user.requireID())

        // save and return token
        return token.save(on: conn)
    }

    public func create(with userContent: CreateUserRequest, conn: DatabaseConnectable) throws -> Future<UserResponse> {

        guard userContent.acceptedTerms else {
            throw UserErrors.missingInput
        }
        guard !userContent.name.isEmpty, !userContent.email.isEmpty, !userContent.password.isEmpty else {
            throw UserErrors.missingInput
        }
        guard userContent.password == userContent.verifyPassword else {
            throw UserErrors.passwordMismatch
        }

        // hash user's password using BCrypt
        let hash = try BCrypt.hash(userContent.password)
        // save new user
        let newUser = User(id: nil, name: userContent.name, email: userContent.email, passwordHash: hash)

        return User.query(on: conn)
            .filter(\.email == newUser.email)
            .first()
            .flatMap { existingUser in

                guard existingUser == nil else {
                    throw UserErrors.existingUser(newUser.email)
                }
                return newUser.save(on: conn)
                    .map { user in
                        try UserResponse(id: user.requireID(), name: user.name, email: user.email, registrationDate: Date())
                }
        }
    }

    public func getAll(on conn: DatabaseConnectable) -> Future<[UserResponse]> {

        return User.query(on: conn)
            .all()
            .map { users in
                try users.map { try $0.content() }
        }
    }
}
