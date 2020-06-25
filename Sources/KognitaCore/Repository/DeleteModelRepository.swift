//
//  DeleteModelRepository.swift
//  KognitaCore
//
//  Created by Mats Mollestad on 22/12/2019.
//

import Vapor
import FluentKit

public protocol DeleteModelRepository {
    func deleteModelWith(id: Int, by user: User?) throws -> EventLoopFuture<Void>
}

extension DeleteModelRepository where Self: DatabaseConnectableRepository {

    public func deleteDatabase<DatabaseModel: Model>(_ modelType: DatabaseModel.Type, modelID: Int) -> EventLoopFuture<Void> where DatabaseModel.IDValue == Int {
        DatabaseModel.find(modelID, on: database)
            .unwrap(or: Abort(.badRequest))
            .delete(on: database)
    }
}
