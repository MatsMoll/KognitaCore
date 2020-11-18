//
//  UserRepository+DatabaseRepository.swift
//  KognitaCore
//
//  Created by Mats Mollestad on 14/11/2020.
//

import Crypto
import Vapor
import FluentKit

extension User {
    /// A `UserRepository` that uses a database implementation
    public struct DatabaseRepository: DatabaseConnectableRepository {

        public init(database: Database, password: PasswordHasher) {
            self.database = database
            self.password = password
        }

        /// The database to connect to
        public let database: Database

        /// The password hasher to use
        let password: PasswordHasher
    }
}

extension String {
    var isValidEmail: Bool {
        if let matchRange = self.range(of: "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}", options: [.regularExpression, .caseInsensitive]) {
            if matchRange == startIndex..<endIndex {
                return true
            }
        }
        return false
    }
}

extension User.DatabaseRepository: UserRepository {

    public func verify(email: String, with password: String) -> EventLoopFuture<User?> {

        User.DatabaseModel.query(on: database)
            .filter(\.$email == email)
            .first()
            .flatMapThrowing { user in
                if
                    let user = user,
                    (try? self.password.verify(password, created: user.passwordHash)) == true
                {
                    return try user.content()
                }
                return nil
        }
    }

    public func user(with token: String) -> EventLoopFuture<User?> {
        User.Login.Token.DatabaseModel.query(on: database)
            .filter(\.$string == token)
            .join(parent: \User.Login.Token.DatabaseModel.$user)
            .first(User.DatabaseModel.self)
            .flatMapThrowing { try $0?.content() }
    }

    public func find(_ id: Int) -> EventLoopFuture<User?> {
        findDatabaseModel(User.DatabaseModel.self, withID: id)
    }
    public func find(_ id: Int, or error: Error) -> EventLoopFuture<User> {
        findDatabaseModel(User.DatabaseModel.self, withID: id, or: Abort(.badRequest))
    }

    public enum Errors: LocalizedError {
        case passwordMismatch
        case missingInput
        case misformed(field: String, reason: String)
        case unauthorized
        case existingUser(email: String)
        case invalidRecruterToken
        case invalidEmail

        public var errorDescription: String? {
            switch self {
            case .missingInput:                     return "Sjekk at all informasjon er skrevet inn"
            case .passwordMismatch:                 return "Passordet må skrives likt to ganger"
            case .unauthorized:                     return "Sjekk at epost og passord stemmer"
            case .existingUser(let email):          return "Det finnes allerede en bruker med epost: \(email)"
            case .invalidRecruterToken:             return "Ugyldig rekrutteringskode"
            case .misformed(let field, let reason): return "Ugyldig formatert \(field) fordi det \(reason)"
            case .invalidEmail:                     return "Ugyldig epost. Må være en NTNU-addresse"
            }
        }
    }

    public func login(with user: User) throws -> EventLoopFuture<User.Login.Token> {
        // create new token for this user
        let token = try User.Login.Token.DatabaseModel.create(userID: user.id)

        // save and return token
        return token.save(on: database)
            .flatMapThrowing { try token.content() }
    }

    public func logLogin(for user: User, with ipAddress: String?) -> EventLoopFuture<Void> {
        User.Login.Log(userID: user.id, ipAddress: ipAddress)
            .save(on: database)
    }

    public func create(from content: User.Create.Data) throws -> EventLoopFuture<User> {

        guard content.hasAcceptedTerms else { throw Errors.missingInput }
        guard !content.username.isEmpty, !content.email.isEmpty, !content.password.isEmpty else {
            throw Errors.missingInput
        }
        guard content.password == content.verifyPassword else {
            throw Errors.passwordMismatch
        }
        let lowercasedEmail = content.email.lowercased()
        guard lowercasedEmail.isValidEmail else {
            throw Errors.misformed(field: "email", reason: "innholder mellomrom eller lignende tegn")
        }
        guard lowercasedEmail.hasSuffix("ntnu.no") else {
            throw Errors.invalidEmail
        }

        // hash user's password using BCrypt
        let hash = try password.hash(content.password)
        // save new user
        let newUser = User.DatabaseModel(
            username: content.username,
            email: content.email,
            passwordHash: hash
        )

        return User.DatabaseModel.query(on: database)
            .filter(\.$email == newUser.email.lowercased())
            .first()
            .flatMap { existingUser in

                guard existingUser == nil else {
                    return self.database.eventLoop.future(error: Errors.existingUser(email: newUser.email))
                }
                return newUser.save(on: self.database)
                    .failableFlatMap {

                        try User.VerifyEmail.Token.DatabaseModel.create(userID: newUser.requireID())
                            .save(on: self.database)
                }
                .flatMapThrowing { try newUser.content() }
        }
    }

    public func first(with email: String) -> EventLoopFuture<User?> {
        User.DatabaseModel.query(on: database)
            .filter(\User.DatabaseModel.$email == email)
            .first()
            .flatMapThrowing { try $0?.content() }
    }

    public func isModerator(user: User, subjectID: Subject.ID) -> EventLoopFuture<Bool> {
        guard user.isAdmin == false else {
            return database.eventLoop.future(true)
        }
        return User.ModeratorPrivilege.query(on: database)
            .filter(\.$subject.$id == subjectID)
            .filter(\User.ModeratorPrivilege.$user.$id == user.id)
            .first()
            .map { $0 != nil }
    }

    public func isModerator(user: User, subtopicID: Subtopic.ID) throws -> EventLoopFuture<Bool> {
        return database.eventLoop.future(error: Abort(.notImplemented))
//        guard user.isAdmin == false else {
//            return conn.future()
//        }
//        return Subtopic.DatabaseModel.query(on: conn)
//            .filter(\.id == subtopicID)
//            .filter(\User.ModeratorPrivilege.userID == user.id)
//            .join(\Topic.DatabaseModel.id, to: \Subtopic.DatabaseModel.topicID)
//            .join(\User.ModeratorPrivilege.subjectID, to: \Topic.DatabaseModel.subjectId)
//            .first()
//            .unwrap(or: Abort(.forbidden))
//            .transform(to: ())
    }

    public func isModerator(user: User, taskID: Task.ID) -> EventLoopFuture<Bool> {
        guard user.isAdmin == false else {
            return database.eventLoop.future(true)
        }
        return TaskDatabaseModel.query(on: database)
            .withDeleted()
            .filter(\.$id == taskID)
            .filter(User.ModeratorPrivilege.self, \User.ModeratorPrivilege.$user.$id == user.id)
            .join(parent: \TaskDatabaseModel.$subtopic)
            .join(parent: \Subtopic.DatabaseModel.$topic)
            .join(parent: \Topic.DatabaseModel.$subject)
            .join(User.ModeratorPrivilege.self, on: \User.ModeratorPrivilege.$subject.$id == \Topic.DatabaseModel.$id)
            .first()
            .map { $0 != nil }
    }

    public func isModerator(user: User, topicID: Topic.ID) throws -> EventLoopFuture<Bool> {
        guard user.isAdmin == false else {
            return database.eventLoop.future(true)
        }
        return Topic.DatabaseModel.query(on: database)
            .filter(\.$id == topicID)
            .filter(User.ModeratorPrivilege.self, \User.ModeratorPrivilege.$user.$id == user.id)
            .join(User.ModeratorPrivilege.self, on: \User.ModeratorPrivilege.$subject.$id == \Topic.DatabaseModel.$subject.$id)
            .first()
            .map { $0 != nil }
    }

    public func canPractice(user: User, subjectID: Subject.ID) -> EventLoopFuture<Bool> {
        guard user.isAdmin == false else {
            return database.eventLoop.future(true)
        }
        guard user.isEmailVerified else {
            return database.eventLoop.future(error: Abort(.forbidden))
        }
        return User.ActiveSubject.query(on: database)
            .filter(\.$user.$id == user.id)
            .filter(\.$subject.$id == subjectID)
            .filter(\.$canPractice == true)
            .first()
            .map { $0 != nil }
    }

    public func verify(user: User, with token: User.VerifyEmail.Token) -> EventLoopFuture<Void> {

        guard user.isEmailVerified == false else {
            return database.eventLoop.future()
        }

        return User.DatabaseModel
            .find(user.id, on: database)
            .unwrap(or: Abort(.badRequest))
            .flatMap { databaseUser in
                User.VerifyEmail.Token.DatabaseModel
                    .query(on: self.database)
                    .filter(\.$token == token.token)
                    .filter(\.$user.$id == user.id)
                    .first()
                    .unwrap(or: Abort(.badRequest))
                    .flatMap { _ in
                        databaseUser.isEmailVerified = true
                        return databaseUser.save(on: self.database)
                }
        }
    }

    public func verifyToken(for userID: User.ID) -> EventLoopFuture<User.VerifyEmail.Token> {
        User.VerifyEmail.Token.DatabaseModel
            .query(on: database)
            .filter(\User.VerifyEmail.Token.DatabaseModel.$user.$id == userID)
            .first()
            .unwrap(or: Abort(.badRequest))
            .map { User.VerifyEmail.Token(token: $0.token) }
    }
}
