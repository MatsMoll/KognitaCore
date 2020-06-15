//
//  DeleteModelRepository.swift
//  KognitaCore
//
//  Created by Mats Mollestad on 22/12/2019.
//

import Vapor
import FluentPostgreSQL

public protocol DeleteModelRepository {
    func deleteModelWith(id: Int, by user: User?) throws -> EventLoopFuture<Void>
}

extension DeleteModelRepository where Self: DatabaseConnectableRepository {

    public func deleteDatabase<DatabaseModel: PostgreSQLModel>(_ modelType: DatabaseModel.Type, modelID: Int) -> EventLoopFuture<Void> {
        DatabaseModel.find(modelID, on: conn)
            .unwrap(or: Abort(.badRequest))
            .flatMap { databaseModel in
                databaseModel.delete(on: self.conn)
        }
    }
}
