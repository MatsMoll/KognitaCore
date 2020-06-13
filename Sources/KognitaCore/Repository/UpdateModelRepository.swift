//
//  EditModelRepository.swift
//  KognitaCore
//
//  Created by Mats Mollestad on 22/12/2019.
//

import FluentPostgreSQL
import Vapor

public protocol UpdateModelRepository {
    associatedtype UpdateData
    associatedtype UpdateResponse
    associatedtype ID

    func updateModelWith(id: ID, to data: UpdateData, by user: User) throws -> EventLoopFuture<UpdateResponse>
}

public protocol DatabaseConnectableRepository {
    var conn: DatabaseConnectable { get }
}

extension UpdateModelRepository
    where
    Self: DatabaseConnectableRepository {
    func updateDatabase<DatabaseModel: KognitaModelUpdatable>(_ type: DatabaseModel.Type, modelID: ID, to data: UpdateData) -> EventLoopFuture<DatabaseModel.ResponseModel> where DatabaseModel: ContentConvertable, DatabaseModel.ResponseModel == UpdateResponse, ID == DatabaseModel.ID, DatabaseModel.EditData == UpdateData {
        DatabaseModel.find(modelID, on: conn)
            .unwrap(or: Abort(.badRequest))
            .flatMap { databaseModel in
                try databaseModel.updateValues(with: data)
                return databaseModel.save(on: self.conn)
                    .map { try $0.content() }
        }
    }
}
