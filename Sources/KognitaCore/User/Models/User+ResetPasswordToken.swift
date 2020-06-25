//
//  User+ResetPasswordToken.swift
//  KognitaCore
//
//  Created by Mats Mollestad on 9/1/19.
//

import Vapor
import FluentKit

extension User {

    public enum ResetPassword {

        public final class Token: KognitaPersistenceModel, SoftDeleatableModel {

            public static var tableName: String = "User.ResetPassword.Token"

            @DBID(custom: "id")
            public var id: Int?

            @Parent(key: "userId")
            var user: User.DatabaseModel

            @Field(key: "string")
            var string: String

            /// The date the token expires
            @Timestamp(key: "deletedAt", on: .delete)
            public var deletedAt: Date?

            @Timestamp(key: "createdAt", on: .create)
            public var createdAt: Date?

            @Timestamp(key: "updatedAt", on: .update)
            public var updatedAt: Date?

            init(userId: User.ID) throws {
                self.$user.id = userId
                self.deletedAt = Date.init(timeInterval: 60 * 60 * 5, since: .init())
                self.string = [UInt8].random(count: 16).base64
            }

            public init() {}
        }
    }
}

extension User.ResetPassword.Token {
    enum Migrations {}
}

extension User.ResetPassword.Token.Migrations {
    struct Create: KognitaModelMigration {

        typealias Model = User.ResetPassword.Token

        func build(schema: SchemaBuilder) -> SchemaBuilder {
            schema.field("string", .string, .required)
                .field("userId", .uint, .required, .references(User.DatabaseModel.schema, .id, onDelete: .cascade, onUpdate: .cascade))
                .field("deletedAt", .date)
                .defaultTimestamps()
        }
    }
}

extension User.ResetPassword.Token {

//    public static func prepare(on conn: PostgreSQLConnection) -> EventLoopFuture<Void> {
//        PostgreSQLDatabase.create(User.ResetPassword.Token.self, on: conn) { builder in
//            try addProperties(to: builder)
//            builder.reference(from: \.userId, to: \User.DatabaseModel.id, onUpdate: .cascade, onDelete: .setDefault)
//        }.flatMap {
//            PostgreSQLDatabase.update(User.ResetPassword.Token.self, on: conn) { builder in
//                builder.deleteField(for: \.userId)
//                builder.field(for: \.userId, type: .int, .default(1))
//            }
//        }
//    }

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

        public let database: Database

        private var userRepository: UserRepository { User.DatabaseRepository(database: database) }
    }
}

extension User.DatabaseRepository: ResetPasswordRepositoring {

    enum ResetErrors: Error {
        case incorrectOrExpiredToken
    }

    public func startReset(for user: User) throws -> EventLoopFuture<User.ResetPassword.Token.Create.Response> {

        let token = try User.ResetPassword.Token(userId: user.id)

        return token.save(on: database)
            .map { .init(token: token.string) }
    }

    public func reset(to content: User.ResetPassword.Data, with token: String) throws -> EventLoopFuture<Void> {

        guard content.password == content.verifyPassword else { throw User.DatabaseRepository.Errors.passwordMismatch }

        return User.ResetPassword.Token
            .query(on: database)
            .filter(\.$string == token)
            .first()
            .unwrap(or: ResetErrors.incorrectOrExpiredToken)
            .flatMap { tokenModel in

                User.DatabaseModel
                    .find(tokenModel.$user.id, on: self.database)
                    .unwrap(or: Abort(.badRequest))
            }
            .flatMapThrowing { try $0.update(password: content.password) }
            .flatMap { $0.save(on: self.database) }
            .transform(to: ())
    }
}
