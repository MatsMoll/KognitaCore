//
//  EditModelRepository.swift
//  KognitaCore
//
//  Created by Mats Mollestad on 22/12/2019.
//

import Vapor
import FluentKit

//public protocol UpdateModelRepository {
//    associatedtype UpdateData
//    associatedtype UpdateResponse
//    associatedtype ID
//
//    func updateModelWith(id: ID, to data: UpdateData, by user: User) throws -> EventLoopFuture<UpdateResponse>
//    func updateModelWith(id: Int, to data: UpdateData, by user: User) throws -> EventLoopFuture<UpdateResponse>
//}

public protocol DatabaseConnectableRepository {
    var database: Database { get }
}

extension DatabaseConnectableRepository {
    func updateDatabase<DatabaseModel: KognitaModelUpdatable>(_ type: DatabaseModel.Type, modelID: Int, to data: DatabaseModel.EditData) -> EventLoopFuture<DatabaseModel.ResponseModel> where DatabaseModel: ContentConvertable, DatabaseModel.IDValue == Int {
        DatabaseModel.find(modelID, on: database)
            .unwrap(or: Abort(.badRequest))
            .flatMapThrowing { databaseModel -> DatabaseModel in
                try databaseModel.updateValues(with: data)
                return databaseModel
            }.flatMap { databaseModel in
                databaseModel.save(on: self.database)
                    .transform(to: databaseModel)
            }
            .flatMapThrowing { try $0.content() }
    }
}

extension EventLoopFuture {
    public func failableFlatMap<Result>(event: @escaping (Value) throws -> EventLoopFuture<Result>) -> EventLoopFuture<Result> {
        flatMap { value in
            do {
                return try event(value)
            } catch {
                return self.eventLoop.future(error: error)
            }
        }
    }
}

func failable<Value>(eventLoop: EventLoop, event: () throws -> EventLoopFuture<Value>) -> EventLoopFuture<Value> {
    do {
        return try event()
    } catch {
        return eventLoop.makeFailedFuture(error)
    }
}
