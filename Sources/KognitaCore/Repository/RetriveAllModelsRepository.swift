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

    func all(where filter: FilterOperator<PostgreSQLDatabase, Model>) -> EventLoopFuture<[Model]> {
        return Model.query(on: conn)
            .filter(filter)
            .all()
    }
}

extension RetriveAllModelsRepository where Model: Identifiable, Self: DatabaseConnectableRepository {

    func all<DatabaseModel: ContentConvertable>(_ modelType: DatabaseModel.Type) -> EventLoopFuture<[DatabaseModel.ResponseModel]> where DatabaseModel: PostgreSQLModel, DatabaseModel.ResponseModel == ResponseModel {
        DatabaseModel.query(on: conn)
            .all()
            .map { try $0.map { try $0.content() } }
    }

    func all<DatabaseModel: ContentConvertable>(where filter: FilterOperator<PostgreSQLDatabase, DatabaseModel>) -> EventLoopFuture<[DatabaseModel.ResponseModel]> where DatabaseModel: PostgreSQLModel, DatabaseModel.ResponseModel == ResponseModel {
        DatabaseModel.query(on: conn)
            .filter(filter)
            .all()
            .map { try $0.map { try $0.content() } }
    }
}

public protocol RetriveModelRepository {
    associatedtype Model
    func find(_ id: Int, or error: Error) -> EventLoopFuture<Model>
    func find(_ id: Int) -> EventLoopFuture<Model?>
}

extension RetriveModelRepository where Model: Identifiable, Self: DatabaseConnectableRepository {

    func findDatabaseModel<DatabaseModel: ContentConvertable>(_ modelType: DatabaseModel.Type, withID id: Model.ID) -> EventLoopFuture<DatabaseModel.ResponseModel?> where DatabaseModel: PostgreSQLModel, Model.ID == DatabaseModel.ID {
        DatabaseModel.find(id, on: conn)
            .map { try $0?.content() }
    }

    func findDatabaseModel<DatabaseModel: ContentConvertable>(_ modelType: DatabaseModel.Type, withID id: Model.ID, or error: Error) -> EventLoopFuture<DatabaseModel.ResponseModel> where DatabaseModel: PostgreSQLModel, Model.ID == DatabaseModel.ID {
        DatabaseModel.find(id, on: conn)
            .unwrap(or: error)
            .map { try $0.content() }
    }

    func first<DatabaseModel: ContentConvertable>(where filter: FilterOperator<PostgreSQLDatabase, DatabaseModel>, or error: Error) -> EventLoopFuture<DatabaseModel.ResponseModel> where DatabaseModel: PostgreSQLModel {
        DatabaseModel.query(on: conn)
            .filter(filter)
            .first()
            .unwrap(or: error)
            .map { try $0.content() }
    }

    func first<DatabaseModel: ContentConvertable>(where filter: FilterOperator<PostgreSQLDatabase, DatabaseModel>, or error: Error) -> EventLoopFuture<DatabaseModel.ResponseModel?> where DatabaseModel: PostgreSQLModel {
        DatabaseModel.query(on: conn)
            .filter(filter)
            .first()
            .map { try $0?.content() }
    }
}
