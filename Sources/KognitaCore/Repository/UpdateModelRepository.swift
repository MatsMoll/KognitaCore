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

    static func update(model: Model, to data: UpdateData, by user: User, on conn: DatabaseConnectable) throws -> EventLoopFuture<UpdateResponse>
}

extension UpdateModelRepository
    where
    Model: KognitaModelUpdatable,
    Model.EditData == UpdateData,
    UpdateResponse == Model
{
    public static func update(model: Model, to data: UpdateData, by user: User, on conn: DatabaseConnectable) throws -> EventLoopFuture<UpdateResponse> {
        guard user.isCreator else {
            throw Abort(.forbidden)
        }
        try model.updateValues(with: data)
        return model.save(on: conn)
    }
}
