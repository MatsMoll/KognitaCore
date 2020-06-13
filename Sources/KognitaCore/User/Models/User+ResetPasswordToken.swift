//
//  User+ResetPasswordToken.swift
//  KognitaCore
//
//  Created by Mats Mollestad on 9/1/19.
//

import Vapor
import FluentPostgreSQL
import Crypto

extension User {

    public enum ResetPassword {

        public struct Token: KognitaPersistenceModel, SoftDeleatableModel {

            public static var tableName: String = "User.ResetPassword.Token"

            public var id: Int?

            public let userId: User.ID

            public let string: String

            /// The date the token expires
            public var deletedAt: Date?
            public var createdAt: Date?
            public var updatedAt: Date?

            init(userId: User.ID) throws {
                self.userId = userId
                self.deletedAt = Date.init(timeInterval: 60 * 60 * 5, since: .init())
                self.string = try CryptoRandom().generateData(count: 16).base64URLEncodedString(options: .init())
            }
        }
    }
}

extension User.ResetPassword.Token {

    public static func prepare(on conn: PostgreSQLConnection) -> EventLoopFuture<Void> {
        PostgreSQLDatabase.create(User.ResetPassword.Token.self, on: conn) { builder in
            try addProperties(to: builder)
            builder.reference(from: \.userId, to: \User.DatabaseModel.id, onUpdate: .cascade, onDelete: .setDefault)
        }.flatMap {
            PostgreSQLDatabase.update(User.ResetPassword.Token.self, on: conn) { builder in
                builder.deleteField(for: \.userId)
                builder.field(for: \.userId, type: .int, .default(1))
            }
        }
    }

    public enum Create {
        public struct Data {
            public init() {}
        }

        public struct Response: Content {
            public let token: String
        }
    }

    public typealias Data = Create.Response
}

extension User.ResetPassword {
    public struct Data: Decodable {
        let password: String
        let verifyPassword: String
    }
}

public protocol ResetPasswordRepositoring {
    func startReset(for user: User) throws -> EventLoopFuture<User.ResetPassword.Token.Create.Response>
    func reset(to content: User.ResetPassword.Data, with token: String) throws -> EventLoopFuture<Void>
}

extension User.ResetPassword.Token {
    public struct DatabaseRepository: DatabaseConnectableRepository {

        typealias DatabaseModel = User.ResetPassword.Token

        public let conn: DatabaseConnectable

        private var userRepository: some UserRepository { User.DatabaseRepository(conn: conn) }
    }
}

extension User.DatabaseRepository: ResetPasswordRepositoring {

    enum ResetErrors: Error {
        case incorrectOrExpiredToken
    }

    public func startReset(for user: User) throws -> EventLoopFuture<User.ResetPassword.Token.Create.Response> {

        return try User.ResetPassword.Token(userId: user.id)
            .save(on: conn)
            .map { token in
                .init(token: token.string)
        }
    }

    public func reset(to content: User.ResetPassword.Data, with token: String) throws -> EventLoopFuture<Void> {

        guard content.password == content.verifyPassword else { throw User.DatabaseRepository.Errors.passwordMismatch }

        return User.ResetPassword.Token
            .query(on: conn)
            .filter(\.string == token)
            .first()
            .unwrap(or: ResetErrors.incorrectOrExpiredToken)
            .flatMap { tokenModel in

                User.DatabaseModel
                    .find(tokenModel.userId, on: self.conn)
                    .unwrap(or: Abort(.badRequest))
                    .flatMap { user in

                        try user.update(password: content.password)
                        return user.save(on: self.conn)
                            .transform(to: ())
                }
        }
    }
}
