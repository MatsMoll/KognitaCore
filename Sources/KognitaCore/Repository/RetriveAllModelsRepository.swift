//
//  RetriveAllRepository.swift
//  KognitaCore
//
//  Created by Mats Mollestad on 22/12/2019.
//

import FluentPostgreSQL

public protocol RetriveAllModelsRepository {
    associatedtype ResponseModel
    associatedtype Model

    func all() throws -> EventLoopFuture<[ResponseModel]>
}

extension RetriveAllModelsRepository where ResponseModel == Model, Model: PostgreSQLModel, Self: DatabaseConnectableRepository {

    public func all() throws -> EventLoopFuture<[ResponseModel]> {
        Model.query(on: conn)
            .all()
    }

    public func all(where filter: FilterOperator<PostgreSQLDatabase, Model>) -> EventLoopFuture<[Model]> {
        return Model.query(on: conn)
            .filter(filter)
            .all()
    }
}

public protocol RetriveModelRepository {
    associatedtype Model
    func find(_ id: Int, or error: Error) -> EventLoopFuture<Model>
    func find(_ id: Int) -> EventLoopFuture<Model?>
}

extension RetriveModelRepository where Model: PostgreSQLModel, Self: DatabaseConnectableRepository {

    public func find(_ id: Model.ID, or error: Error) -> EventLoopFuture<Model> {
        return Model.find(id, on: conn)
            .unwrap(or: error)
    }

    public func find(_ id: Model.ID) -> EventLoopFuture<Model?> {
        return Model.find(id, on: conn)
    }

    public func first(where filter: FilterOperator<PostgreSQLDatabase, Model>) -> EventLoopFuture<Model?> {
        return Model.query(on: conn)
            .filter(filter)
            .first()
    }

    public func first(where filter: FilterOperator<PostgreSQLDatabase, Model>, or error: Error) -> EventLoopFuture<Model> {
        return Model.query(on: conn)
            .filter(filter)
            .first()
            .unwrap(or: error)
    }
}
