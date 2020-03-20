//
//  PostgreSQLModel+Parameter.swift
//  App
//
//  Created by Mats Mollestad on 05/02/2019.
//

import Foundation
import Vapor
import FluentPostgreSQL


public protocol ModelParameterRepresentable: Parameter {
    associatedtype ParameterModel
    static func resolveParameter(_ parameter: String, conn: DatabaseConnectable) -> EventLoopFuture<ParameterModel>
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
    public func model<T: ModelParameterRepresentable>(_ model: T.Type, on conn: DatabaseConnectable) -> EventLoopFuture<T.ParameterModel> {
        guard let parameter = self.rawValues(for: T.self).first else {
            return conn.future(error: Abort(.badRequest))
        }
        return T.resolveParameter(parameter, conn: conn)
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
