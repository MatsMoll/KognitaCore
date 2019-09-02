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
    
    public struct ResetPassword {
            
        public struct Token : KognitaPersistenceModel, SoftDeleatableModel {
            
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
                self.string = try CryptoRandom().generateData(count: 16).base64EncodedString()
            }
        }
    }
}

extension User.ResetPassword.Token {
    public static func addTableConstraints(to builder: SchemaCreator<User.ResetPassword.Token>) {
        builder.reference(from: \.userId, to: \User.id)
    }
    
    public struct Create : KognitaRequestData {
        public struct Data {
            public init() {}
        }
        
        public struct Response : Content {
            public let token: String
        }
    }
}

extension User.ResetPassword {
    public struct Data : Decodable {
        let password: String
        let verifyPassword: String
    }
}

extension User.ResetPassword.Token {
    public final class Repository : KognitaRepository, KognitaRepositoryDeletable {
        
        public static let shared = Repository()
        
        public typealias Model = User.ResetPassword.Token
    }
}

extension User.ResetPassword.Token.Repository {
    
    enum Errors : Error {
        case incorrectOrExpiredToken
    }
    
    public func create(from content: User.ResetPassword.Token.Create.Data = .init(), by user: User?, on conn: DatabaseConnectable) throws -> EventLoopFuture<User.ResetPassword.Token.Create.Response> {
        
        guard let user = user else { throw Abort(.unauthorized) }
        
        return try User.ResetPassword
            .Token(userId: user.requireID())
            .save(on: conn)
            .map { token in
                .init(token: token.string)
        }
    }
    
    public func delete(_ model: User.ResetPassword.Token, by user: User?, on conn: DatabaseConnectable) throws -> EventLoopFuture<Void> {
        
        guard try user?.requireID() == model.userId else {
            throw Abort(.forbidden)
        }
        return model.delete(on: conn)
            .transform(to: ())
    }
    
    public func reset(to content: User.ResetPassword.Data, with token: String, by user: User, on conn: DatabaseConnectable) throws -> Future<Void> {
        
        guard content.password == content.verifyPassword else { throw User.Repository.Errors.passwordMismatch }
        
        return User.ResetPassword.Token.repository
            .first(where: \.string == token, or: Errors.incorrectOrExpiredToken, on: conn)
            .flatMap { tokenModel in
                
                guard try user.requireID() == tokenModel.userId else { throw Abort(.forbidden) }
                
                try user.update(password: content.password)
                return user.save(on: conn)
                    .transform(to: ())
        }
    }
}
