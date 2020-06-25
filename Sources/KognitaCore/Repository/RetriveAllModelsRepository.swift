//
//  RetriveAllRepository.swift
//  KognitaCore
//
//  Created by Mats Mollestad on 22/12/2019.
//

import FluentKit

//public protocol RetriveAllModelsRepository {
//    associatedtype ResponseModel
//    associatedtype Model
//
//    func all() throws -> EventLoopFuture<[ResponseModel]>
//}
//
//extension RetriveAllModelsRepository where ResponseModel == Model, Model: PostgreSQLModel, Self: DatabaseConnectableRepository {
//
//    public func all() throws -> EventLoopFuture<[ResponseModel]> {
//        Model.query(on: conn)
//            .all()
//    }
//
//    func all(where filter: FilterOperator<PostgreSQLDatabase, Model>) -> EventLoopFuture<[Model]> {
//        return Model.query(on: conn)
//            .filter(filter)
//            .all()
//    }
//}

extension DatabaseConnectableRepository {

    func all<DatabaseModel: ContentConvertable>(_ modelType: DatabaseModel.Type) -> EventLoopFuture<[DatabaseModel.ResponseModel]> where DatabaseModel: Model {
        DatabaseModel.query(on: database)
            .all()
            .flatMapEachThrowing { try $0.content() }
    }
}

//public protocol RetriveModelRepository {
//    associatedtype Model: Identifiable
//    func find(_ id: Int, or error: Error) -> EventLoopFuture<Model>
//    func find(_ id: Int) -> EventLoopFuture<Model?>
//}

extension DatabaseConnectableRepository {

    func findDatabaseModel<DatabaseModel: ContentConvertable>(_ modelType: DatabaseModel.Type, withID id: Int) -> EventLoopFuture<DatabaseModel.ResponseModel?> where DatabaseModel: Model, DatabaseModel.IDValue == Int {
        DatabaseModel.find(id, on: database)
            .flatMapThrowing { try $0?.content() }
    }

    func findDatabaseModel<DatabaseModel: ContentConvertable>(_ modelType: DatabaseModel.Type, withID id: Int, or error: Error) -> EventLoopFuture<DatabaseModel.ResponseModel> where DatabaseModel: Model, DatabaseModel.IDValue == Int {
        DatabaseModel.find(id, on: database)
            .unwrap(or: error)
            .content()
    }
}
