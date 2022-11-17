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

extension User.Create.Data: UserRepresentable {
    public var usedPassword: String? { password }

    public var isEmailVerified: Bool { false }

    public var origin: String { "Kognita" }
}

extension User.DatabaseRepository: UserRepository {

    public func verify(email: String, with password: String) -> EventLoopFuture<User?> {

        User.DatabaseModel.query(on: database)
            .filter(\.$email == email)
            .join(superclass: KognitaUser.self, with: User.DatabaseModel.self)
            .first(User.DatabaseModel.self, KognitaUser.self)
            .flatMapThrowing { (userContent) in
                if
                    let (user, kognitaUser) = userContent,
                    (try? self.password.verify(password, created: kognitaUser.passwordHash)) == true
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
        case existingUsername(username: String)
        case invalidRecruterToken
        case invalidEmail

        public var errorDescription: String? {
            switch self {
            case .missingInput:                     return "Sjekk at all informasjon er skrevet inn"
            case .passwordMismatch:                 return "Passordet må skrives likt to ganger"
            case .unauthorized:                     return "Sjekk at epost og passord stemmer"
            case .existingUser(let email):          return "Det finnes allerede en bruker med epost: \(email)"
            case .existingUsername(let username):   return "Det finnes allerede en bruker med brukernavnet: \(username)"
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

    public func loginWith(feide tokenConfig: TokenConfig, for userID: User.ID) throws -> EventLoopFuture<User.Login.Token> {
        let token = User.Login.Token.DatabaseModel(string: tokenConfig.token, expiresAt: tokenConfig.expiresAt, userID: userID)
        return token.create(on: database)
            .failableFlatMap {
                try FeideUser.Token(id: token.requireID())
                    .create(on: database)
                    .transform(to: token)
            }
            .flatMapThrowing { try $0.content() }
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

        return try unsafeCreate(content, handleDuplicateSilently: false)
    }

    public func unsafeCreate(_ user: UserRepresentable, handleDuplicateSilently: Bool) throws -> EventLoopFuture<User> {

        let newUser = User.DatabaseModel(
            username: user.username,
            email: user.email.lowercased(),
            pictureUrl: user.pictureUrl,
            isEmailVerified: user.isEmailVerified
        )

        return User.DatabaseModel.query(on: database)
            .group(.or) {
                $0
                    .filter(\.$email == newUser.email)
                    .filter(\.$username == newUser.username)
            }
            .first()
            .flatMap { existingUser in
                if
                    !handleDuplicateSilently, // If it should throw an error on duplicate user
                    let dbUser = existingUser
                {
                    if dbUser.username == newUser.username {
                        return self.database.eventLoop.future(error: Errors.existingUsername(username: newUser.username))
                    } else {
                        return self.database.eventLoop.future(error: Errors.existingUser(email: newUser.email))
                    }
                }

                return newUser.save(on: database)
                    .failableFlatMap {
                        let userID = try newUser.requireID()
                        // If a passowrd is used, then it is a Kognita user otherwise Feide
                        if let userPassword = user.usedPassword {
                            return try KognitaUser(
                                id: userID,
                                passwordHash: password.hash(userPassword)
                            )
                            .create(on: database)
                        } else {
                            return FeideUser(id: userID).create(on: database)
                        }
                    }
                    .failableFlatMap {
                        if !user.isEmailVerified {
                            return try User.VerifyEmail.Token.DatabaseModel.create(userID: newUser.requireID())
                                .save(on: database)
                        } else {
                            return database.eventLoop.future()
                        }
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

    public func saveFeide(grant: Feide.Grant, for userID: User.ID) -> EventLoopFuture<Void> {
        Feide.Grant.DatabaseModel(grant: grant, userID: userID)
            .create(on: database)
    }

    public func latestFeideGrant(for userID: User.ID) -> EventLoopFuture<Feide.Grant?> {
        Feide.Grant.DatabaseModel.query(on: database)
            .sort(\.$createdAt, .descending)
            .filter(\.$loggedOutAt == nil)
            .first()
            .map { grant in
                guard let grant = grant else { return nil }
                return Feide.Grant(code: grant.token, state: nil)
            }
    }

    public func markAsOutdated(grant: Feide.Grant, for userID: User.ID) -> EventLoopFuture<Void> {
        Feide.Grant.DatabaseModel.query(on: database)
            .filter(\.$token == grant.code)
            .filter(\.$user.$id == userID)
            .first()
            .unwrap(or: Abort(.badRequest))
            .flatMap { grant in
                grant.loggedOutAt = .now
                return grant.save(on: database)
            }
    }

    public func latestFeideToken(for userID: User.ID) -> EventLoopFuture<User.Login.Token?> {
        FeideUser.Token.query(on: database)
            .join(superclass: User.Login.Token.DatabaseModel.self, with: FeideUser.Token.self)
            .filter(User.Login.Token.DatabaseModel.self, \User.Login.Token.DatabaseModel.$user.$id == userID)
            .filter(User.Login.Token.DatabaseModel.self, \User.Login.Token.DatabaseModel.$expiresAt < Date())
            .first(User.Login.Token.DatabaseModel.self)
            .flatMapThrowing { try $0?.content() }
    }
    
    public func numberOfUsers() -> EventLoopFuture<Int> {
        return User.DatabaseModel.query(on: database).count()
    }
}
