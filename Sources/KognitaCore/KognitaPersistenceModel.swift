//
//  KognitaPersistenceModel.swift
//  KognitaCore
//
//  Created by Mats Mollestad on 8/29/19.
//

import Vapor
import FluentPostgreSQL


//extension KognitaRepositoryDeletable {
//    static public func delete(_ model: Model, by user: User?, on conn: DatabaseConnectable) throws -> Future<Void> {
//        guard let user = user,
//            user.isCreator else { throw Abort(.forbidden) }
//        return model.delete(on: conn)
//    }
//}
//
public protocol KognitaModelUpdatable : KognitaCRUDModel {

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
public protocol KognitaPersistenceModel : PostgreSQLModel, Migration {

    /// Creation at data
    var createdAt: Date? { get set }

    /// Updated at data
    var updatedAt: Date? { get set }

    /// Adds constraints to the database table
    ///
    /// - Parameter builder: The builder that builds the table
    static func addTableConstraints(to builder: SchemaCreator<Self>)
}

extension KognitaPersistenceModel {

    public static var createdAtKey: WritableKeyPath<Self, Date?>? { return \Self.createdAt }
    public static var updatedAtKey: WritableKeyPath<Self, Date?>? { return \Self.updatedAt }

    public static func prepare(on conn: PostgreSQLConnection) -> Future<Void> {
        return PostgreSQLDatabase.create(Self.self, on: conn) { builder in
            try addProperties(to: builder)
            Self.addTableConstraints(to: builder)
        }
    }

    public static func revert(on connection: PostgreSQLConnection) -> Future<Void> {
        return PostgreSQLDatabase.delete(Self.self, on: connection)
    }

    public static func addTableConstraints(to builder: SchemaCreator<Self>) {}
}
//
//public typealias KognitaCRUDRepository = KognitaRepositoryDeletable & KognitaRepositoryEditable
//
public protocol KognitaCRUDModel : KognitaPersistenceModel {
    
}

public protocol SoftDeleatableModel : KognitaPersistenceModel {

    /// The date a modal was deleted at
    var deletedAt: Date? { get set }
}

extension SoftDeleatableModel {
    public static var deletedAtKey: WritableKeyPath<Self, Date?>? { return \Self.deletedAt }
}
