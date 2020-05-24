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

    func delete(model: Model, by user: User?) throws -> EventLoopFuture<Void>
}

extension DeleteModelRepository where Model: PostgreSQLModel, Self: DatabaseConnectableRepository {
    public func delete(model: Model, by user: User?) throws -> EventLoopFuture<Void> {
        return model.delete(on: conn)
    }
}
