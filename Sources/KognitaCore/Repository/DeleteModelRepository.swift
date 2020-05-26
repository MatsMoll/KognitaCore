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

extension DeleteModelRepository where Self: DatabaseConnectableRepository, Model: Identifiable {

    public func deleteDatabase<DatabaseModel: PostgreSQLModel>(_ modelType: DatabaseModel.Type, model: Model) -> EventLoopFuture<Void> where Model.ID == DatabaseModel.ID {
        DatabaseModel.find(model.id, on: conn)
            .unwrap(or: Abort(.badRequest))
            .flatMap { databaseModel in
                databaseModel.delete(on: self.conn)
        }
    }
}
