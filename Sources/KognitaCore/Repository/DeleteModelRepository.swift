//
//  DeleteModelRepository.swift
//  KognitaCore
//
//  Created by Mats Mollestad on 22/12/2019.
//

import Vapor
import FluentPostgreSQL

public protocol DeleteModelRepository {
    associatedtype Model

    static func delete(model: Model, by user: User?, on conn: DatabaseConnectable) throws -> EventLoopFuture<Void>
}

extension DeleteModelRepository where Model: PostgreSQLModel {
    public static func delete(model: Model, by user: User?, on conn: DatabaseConnectable) throws -> EventLoopFuture<Void> {
        guard let user = user else {
            throw Abort(.unauthorized)
        }
        guard user.isCreator else {
            throw Abort(.forbidden)
        }
        return model.delete(on: conn)
    }
}
