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

        return try container.connectionPool(to: .psql)
            .withConnection { conn in

                Self.find(id, on: conn)
                    .unwrap(or: Abort(.internalServerError))
        }
    }
}
