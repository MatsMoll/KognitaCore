//
//  PostgreSQLModel+Parameter.swift
//  App
//
//  Created by Mats Mollestad on 05/02/2019.
//

import Foundation
import Vapor
import FluentPostgreSQL

extension PostgreSQLModel where Self: Parameter {
    public static func resolveParameter(_ parameter: String, on container: Container) throws -> EventLoopFuture<Self> {
        guard let id = Int(parameter) else {
            throw Abort(.badRequest, reason: "Was not able to interpret \(parameter) as `Int`.")
        }
        return container.requestCachedConnection(to: .psql).flatMap { (connection) in
            return Self.find(id, on: connection)
                .unwrap(or: Abort(.internalServerError))
            }
    }
}
