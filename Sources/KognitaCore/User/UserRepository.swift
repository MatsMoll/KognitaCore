//
//  UserRepository.swift
//  KognitaCore
//
//  Created by Mats Mollestad on 11/04/2019.
//

import Crypto
import Vapor
import FluentKit

extension EventLoopFuture where Value: ContentConvertable {
    func content() -> EventLoopFuture<Value.ResponseModel> {
        flatMapThrowing { try $0.content() }
    }
}

public protocol UserRepository: ResetPasswordRepositoring {

    func find(_ id: User.ID) -> EventLoopFuture<User?>
    func find(_ id: User.ID, or error: Error) -> EventLoopFuture<User>

    func create(from content: User.Create.Data, by user: User?) throws -> EventLoopFuture<User>

    func login(with user: User) throws -> EventLoopFuture<User.Login.Token>
    func verify(email: String, with password: String) -> EventLoopFuture<User?>
    func user(with token: String) -> EventLoopFuture<User?>

    func first(with email: String) -> EventLoopFuture<User?>

    func isModerator(user: User, subjectID: Subject.ID) throws -> EventLoopFuture<Bool>
    func isModerator(user: User, subtopicID: Subtopic.ID) throws -> EventLoopFuture<Bool>
    func isModerator(user: User, taskID: Task.ID) throws -> EventLoopFuture<Bool>
    func isModerator(user: User, topicID: Topic.ID) throws -> EventLoopFuture<Bool>

    func canPractice(user: User, subjectID: Subject.ID) throws -> EventLoopFuture<Void>

    func verify(user: User, with token: User.VerifyEmail.Request) throws -> EventLoopFuture<Void>
    func verifyToken(for userID: User.ID) throws -> EventLoopFuture<User.VerifyEmail.Token>
}

extension User {
    public struct DatabaseRepository: DatabaseConnectableRepository {

        public init(database: Database) {
            self.database = database
        }

        public let database: Database
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
        database.eventLoop.future(error: Abort(.notImplemented))
    }

    public func user(with token: String) -> EventLoopFuture<User?> {
        database.eventLoop.future(error: Abort(.notImplemented))
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

    public func create(from content: User.Create.Data, by user: User?) throws -> EventLoopFuture<User> {

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
        return database.eventLoop.future(error: Abort(.notImplemented))
//        let hash = try BCrypt.hash(content.password)
//        // save new user
//        let newUser = User.DatabaseModel(
//            username: content.username,
//            email: content.email,
//            passwordHash: hash
//        )
//
//        return User.DatabaseModel.query(on: database)
//            .filter(\.email == newUser.email.lowercased())
//            .first()
//            .flatMap { existingUser in
//
//                guard existingUser == nil else {
//                    throw Errors.existingUser(email: newUser.email)
//                }
//                return newUser.save(on: self.conn)
//                    .flatMap { user in
//
//                        try User.VerifyEmail.Token.create(userID: user.requireID())
//                            .save(on: self.conn)
//                            .transform(to: user)
//                }
//                    .map { try $0.content() }
//        }
    }

    public func first(with email: String) -> EventLoopFuture<User?> {
        User.DatabaseModel.query(on: database)
            .filter(\User.DatabaseModel.$email == email)
            .first()
            .flatMapThrowing { try $0?.content() }
    }

    public func isModerator(user: User, subjectID: Subject.ID) throws -> EventLoopFuture<Bool> {
        guard user.isAdmin == false else {
            return database.eventLoop.future(true)
        }
        return database.eventLoop.future(error: Abort(.notImplemented))
//        return User.ModeratorPrivilege
//            .query(on: conn)
//            .filter(\.subjectID == subjectID)
//            .filter(\User.ModeratorPrivilege.userID == user.id)
//            .first()
//            .unwrap(or: Abort(.forbidden))
//            .transform(to: ())
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

    public func isModerator(user: User, taskID: Task.ID) throws -> EventLoopFuture<Bool> {
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
        return database.eventLoop.future(error: Abort(.notImplemented))
//        guard user.isAdmin == false else {
//            return conn.future()
//        }
//        return Topic.DatabaseModel.query(on: conn)
//            .filter(\.id == topicID)
//            .filter(\User.ModeratorPrivilege.userID == user.id)
//            .join(\User.ModeratorPrivilege.subjectID, to: \Topic.DatabaseModel.subjectId)
//            .first()
//            .unwrap(or: Abort(.forbidden))
//            .transform(to: ())
    }

    public func canPractice(user: User, subjectID: Subject.ID) throws -> EventLoopFuture<Void> {
        return database.eventLoop.future(error: Abort(.notImplemented))
//        guard user.isAdmin == false else {
//            return conn.future()
//        }
//        guard user.isEmailVerified else {
//            throw Abort(.forbidden)
//        }
//        return User.ActiveSubject.query(on: conn)
//            .filter(\.userID == user.id)
//            .filter(\.subjectID == subjectID)
//            .filter(\.canPractice == true)
//            .first()
//            .unwrap(or: Abort(.forbidden))
//            .transform(to: ())
    }

    public func verify(user: User, with token: User.VerifyEmail.Request) throws -> EventLoopFuture<Void> {
        return database.eventLoop.future(error: Abort(.notImplemented))
//
//        guard user.isEmailVerified == false else {
//            return conn.future()
//        }
//        return User.DatabaseModel
//            .find(user.id, on: self.conn)
//            .unwrap(or: Abort(.badRequest))
//            .flatMap { user in
//                try User.VerifyEmail.Token
//                    .query(on: self.conn)
//                    .filter(\.token == token.token)
//                    .filter(\.userID == user.requireID())
//                    .first()
//                    .unwrap(or: Abort(.badRequest))
//                    .flatMap { _ in
//                        user.isEmailVerified = true
//                        return user.save(on: self.conn)
//                            .transform(to: ())
//                }
//        }
    }

    public func verifyToken(for userID: User.ID) throws -> EventLoopFuture<User.VerifyEmail.Token> {
        User.VerifyEmail.Token
            .query(on: database)
            .filter(\User.VerifyEmail.Token.$user.$id == userID)
            .first()
            .unwrap(or: Abort(.internalServerError))
    }
}
