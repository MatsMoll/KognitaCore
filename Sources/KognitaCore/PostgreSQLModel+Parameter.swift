//
//  PostgreSQLModel+Parameter.swift
//  App
//
//  Created by Mats Mollestad on 05/02/2019.
//

import Foundation
import Vapor
import FluentPostgreSQL

public protocol MayBeExpressibleByStringLiteral {
    static func expressedBy(string: String) -> Self?
}

extension Int: MayBeExpressibleByStringLiteral {
    public static func expressedBy(string: String) -> Int? { Int(string) }
}

public protocol ModelParameterRepresentable: Parameter where ResolvedParameter == Never {
    associatedtype ID: MayBeExpressibleByStringLiteral
}

extension ModelParameterRepresentable {
    public static func resolveParameter(_ parameter: String, on container: Container) throws -> Never {
        throw Abort(.notImplemented)
    }
}

extension PostgreSQLModel where Self: ModelParameterRepresentable {

    public typealias ParameterModel = Self

    public static func resolveParameter(_ parameter: String, conn: DatabaseConnectable) -> EventLoopFuture<Self> {
        guard let id = Int(parameter) else {
            return conn.future(error: Abort(.badRequest, reason: "Was not able to interpret \(parameter) as `Int`."))
        }
        return Self.find(id, on: conn)
            .unwrap(or: Abort(.badRequest))
    }
}

extension ParametersContainer {
    public func modelID<T: ModelParameterRepresentable>(_ model: T.Type) throws -> T.ID {
        guard
            let parameter = self.rawValues(for: T.self).first,
            let id = T.ID.expressedBy(string: parameter)
        else {
            throw Abort(.badRequest)
        }
        return id
    }
}

extension Request {
    public func first<T: Parameter>(_ parameter: T.Type) throws -> T.ResolvedParameter {
        guard let parameter = self.parameters.rawValues(for: T.self).first else {
            throw Abort(.badRequest)
        }
        return try T.resolveParameter(parameter, on: self)
    }
}

extension PostgreSQLModel where Self: Parameter {
    public static func resolveParameter(_ parameter: String, on container: Container) throws -> EventLoopFuture<Self> {
        throw Abort(.notImplemented)
    }
}
