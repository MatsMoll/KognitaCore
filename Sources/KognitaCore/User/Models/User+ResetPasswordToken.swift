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
            
        public struct Token : KognitaPersistenceModel, SoftDeleatableModel {

            public static var entity: String = "User.ResetPassword.Token"
            public static var name: String = "User.ResetPassword.Token"
            
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
            builder.reference(from: \.userId, to: \User.id, onUpdate: .cascade, onDelete: .setDefault)
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
        
        public struct Response : Content {
            public let token: String
        }
    }

    public typealias Data = Create.Response
}

extension User.ResetPassword {
    public struct Data : Decodable {
        let password: String
        let verifyPassword: String
    }
}


protocol ResetPasswordRepositoring:
    CreateModelRepository,
    DeleteModelRepository,
    RetriveModelRepository
    where
    CreateData      == User.ResetPassword.Token.Create.Data,
    CreateResponse  == User.ResetPassword.Token.Create.Response,
    Model           == User.ResetPassword.Token
{
    static func reset(to content: User.ResetPassword.Data, with token: String, on conn: DatabaseConnectable) throws -> EventLoopFuture<Void>
}

extension User.ResetPassword.Token {
    public final class Repository {}
}

extension User.ResetPassword.Token.Repository: ResetPasswordRepositoring {
    
    enum Errors : Error {
        case incorrectOrExpiredToken
    }
    
    public static func create(from content: User.ResetPassword.Token.Create.Data = .init(), by user: User?, on conn: DatabaseConnectable) throws -> EventLoopFuture<User.ResetPassword.Token.Create.Response> {
        
        guard let user = user else { throw Abort(.unauthorized) }
        
        return try User.ResetPassword
            .Token(userId: user.requireID())
            .save(on: conn)
            .map { token in
                .init(token: token.string)
        }
    }
    
    public static func delete(model: User.ResetPassword.Token, by user: User?, on conn: DatabaseConnectable) throws -> EventLoopFuture<Void> {
        
        guard try user?.requireID() == model.userId else {
            throw Abort(.forbidden)
        }
        return model.delete(on: conn)
            .transform(to: ())
    }
    
    public static func reset(to content: User.ResetPassword.Data, with token: String, on conn: DatabaseConnectable) throws -> EventLoopFuture<Void> {
        
        guard content.password == content.verifyPassword else { throw User.DatabaseRepository.Errors.passwordMismatch }

        return User.ResetPassword.Token.Repository
            .first(where: \.string == token, or: Errors.incorrectOrExpiredToken, on: conn)
            .flatMap { tokenModel in

                User.DatabaseRepository
                    .find(tokenModel.userId, or: Abort(.internalServerError), on: conn)
                    .flatMap { user in

                        try user.update(password: content.password)
                        return user.save(on: conn)
                            .transform(to: ())
                }
        }
    }
}
