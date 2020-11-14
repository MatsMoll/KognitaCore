//
//  DeleteModelRepository.swift
//  KognitaCore
//
//  Created by Mats Mollestad on 22/12/2019.
//

import Vapor
import FluentKit

/// A repository that contains a delete functionality
public protocol DeleteModelRepository {
    /// Deletes a model from a repository
    /// - Parameters:
    ///   - id: The id assosiated with the model to delete
    ///   - user: The user requestion the delete
    func deleteModelWith(id: Int, by user: User?) throws -> EventLoopFuture<Void>
}

extension DeleteModelRepository where Self: DatabaseConnectableRepository {

    /// A helper function for database repositories that adds a delete method
    /// - Parameters:
    ///   - modelType: The database model to delete
    ///   - modelID: The id of the model to delete
    /// - Returns: Returns a future
    public func deleteDatabase<DatabaseModel: Model>(_ modelType: DatabaseModel.Type, modelID: Int) -> EventLoopFuture<Void> where DatabaseModel.IDValue == Int {
        DatabaseModel.find(modelID, on: database)
            .unwrap(or: Abort(.badRequest))
            .delete(on: database)
    }
}
