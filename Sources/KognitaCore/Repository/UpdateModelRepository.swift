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
    associatedtype Model

    func update(model: Model, to data: UpdateData, by user: User) throws -> EventLoopFuture<UpdateResponse>
}

public protocol DatabaseConnectableRepository {
    var conn: DatabaseConnectable { get }
}

extension UpdateModelRepository
    where
    Self: DatabaseConnectableRepository,
    Model: KognitaModelUpdatable,
    Model.EditData == UpdateData,
    UpdateResponse == Model {
    public func update(model: Model, to data: UpdateData, by user: User) throws -> EventLoopFuture<UpdateResponse> {
        try model.updateValues(with: data)
        return model.save(on: conn)
    }
}
