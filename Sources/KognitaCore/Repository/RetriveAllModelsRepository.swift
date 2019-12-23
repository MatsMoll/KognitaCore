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

    static func all(on conn: DatabaseConnectable) throws -> EventLoopFuture<[ResponseModel]>
}

extension RetriveAllModelsRepository where ResponseModel == Model, Model: PostgreSQLModel {

    public static func all(on conn: DatabaseConnectable) throws -> EventLoopFuture<[ResponseModel]> {
        Model.query(on: conn)
            .all()
    }

    static public func all(where filter: FilterOperator<PostgreSQLDatabase, Model>, on conn: DatabaseConnectable) -> EventLoopFuture<[Model]> {
        return Model.query(on: conn)
            .filter(filter)
            .all()
    }
}

public protocol RetriveModelRepository {
    associatedtype Model
}

extension RetriveModelRepository where Model: PostgreSQLModel {

    public static func find(_ id: Model.ID, or error: Error, on conn: DatabaseConnectable) -> EventLoopFuture<Model> {
        return Model.find(id, on: conn)
            .unwrap(or: error)
    }

    public static func find(_ id: Model.ID, on conn: DatabaseConnectable) -> EventLoopFuture<Model?> {
        return Model.find(id, on: conn)
    }

    public static func first(where filter: FilterOperator<PostgreSQLDatabase, Model>, on conn: DatabaseConnectable) -> EventLoopFuture<Model?> {
        return Model.query(on: conn)
            .filter(filter)
            .first()
    }

    public static func first(where filter: FilterOperator<PostgreSQLDatabase, Model>, or error: Error, on conn: DatabaseConnectable) -> EventLoopFuture<Model> {
        return Model.query(on: conn)
            .filter(filter)
            .first()
            .unwrap(or: error)
    }
}
