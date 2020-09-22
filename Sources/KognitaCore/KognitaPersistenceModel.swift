//
//  KognitaPersistenceModel.swift
//  KognitaCore
//
//  Created by Mats Mollestad on 8/29/19.
//

import Vapor
import Fluent

//extension KognitaRepositoryDeletable {
//    static public func delete(_ model: Model, by user: User?, on conn: DatabaseConnectable) throws -> Future<Void> {
//        guard let user = user,
//            user.isCreator else { throw Abort(.forbidden) }
//        return model.delete(on: conn)
//    }
//}
//
public protocol KognitaModelUpdatable: KognitaCRUDModel {

    associatedtype EditData

    func updateValues(with content: EditData) throws
}
//
//public protocol KognitaRepositoryEditable : KognitaRepository where Model : KognitaCRUDModel {
//    /// Edit a Model
//    ///
//    /// - Parameter model: The model to edit
//    /// - Parameter content: The data defining the new Model
//    /// - Parameter user: The user editing
//    /// - Parameter conn: The database connection
//    static func edit(_ model: Model, to content: Model.Edit.Data, by user: User, on conn: DatabaseConnectable) throws -> Future<Model.Edit.Response>
//}
//
//extension KognitaRepositoryEditable where Model : KognitaModelUpdatable, Model.Edit.Response == Model {
//    static public func edit(_ model: Model, to content: Model.Edit.Data, by user: User, on conn: DatabaseConnectable) throws -> Future<Model.Edit.Response> {
//
//        guard user.isCreator else { throw Abort(.forbidden) }
//
//        try model.updateValues(with: content)
//        return model.save(on: conn)
//    }
//}
//
/// A protocol that defines a Model to be used in Kognita
public protocol KognitaPersistenceModel: Model {

    static var tableName: String { get }

    /// Creation at data
    var createdAt: Date? { get set }

    /// Updated at data
    var updatedAt: Date? { get set }

}

extension KognitaPersistenceModel {
    public static var schema: String { tableName }
}
//
//public typealias KognitaCRUDRepository = KognitaRepositoryDeletable & KognitaRepositoryEditable
//
public protocol KognitaCRUDModel: KognitaPersistenceModel {

}

public protocol SoftDeleatableModel: KognitaPersistenceModel {

    /// The date a modal was deleted at
    var deletedAt: Date? { get set }
}

extension SoftDeleatableModel {
    public static var deletedAtKey: WritableKeyPath<Self, Date?>? { return \Self.deletedAt }
}

public protocol ContentConvertable {
    associatedtype ResponseModel
    func content() throws -> ResponseModel
}
