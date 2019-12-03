//
//  KognitaPersistenceModel.swift
//  KognitaCore
//
//  Created by Mats Mollestad on 8/29/19.
//

import Vapor
import FluentPostgreSQL

public protocol KognitaRequestData {
    associatedtype Data
    associatedtype Response : Content
}

/// A protocol for a Repository that can fetch and modify Model info in a database
public protocol KognitaRepository {
    associatedtype Model where Model : KognitaPersistenceModel
    
    /// Creates a Model
    ///
    /// - Parameter content: The data defining the model
    /// - Parameter user: The user creating the model
    /// - Parameter conn: The database connection
    static func create(from content: Model.Create.Data, by user: User?, on conn: DatabaseConnectable) throws -> Future<Model.Create.Response>
    
    static func first(where filter: FilterOperator<PostgreSQLDatabase, Model>, or error: Error, on conn: DatabaseConnectable) -> Future<Model>
    static func first(where filter: FilterOperator<PostgreSQLDatabase, Model>, on conn: DatabaseConnectable) -> Future<Model?>
    static func all(on conn: DatabaseConnectable) -> Future<[Model]>
    static func all(where filter: FilterOperator<PostgreSQLDatabase, Model>, on conn: DatabaseConnectable) -> Future<[Model]>
    static func find(_ id: Model.ID, or error: Error, on conn: DatabaseConnectable) -> Future<Model>
    static func find(_ id: Model.ID, on conn: DatabaseConnectable) -> Future<Model?>
}

extension KognitaRepository {
    
    static public func first(where filter: FilterOperator<PostgreSQLDatabase, Model>, or error: Error, on conn: DatabaseConnectable) -> Future<Model> {
        return Model.query(on: conn)
            .filter(filter)
            .first()
            .unwrap(or: error)
    }
    
    static public func first(where filter: FilterOperator<PostgreSQLDatabase, Model>, on conn: DatabaseConnectable) -> Future<Model?> {
        return Model.query(on: conn)
            .filter(filter)
            .first()
    }
    
    static public func all(on conn: DatabaseConnectable) -> Future<[Model]> {
        return Model.query(on: conn)
            .all()
    }
    
    static public func all(where filter: FilterOperator<PostgreSQLDatabase, Model>, on conn: DatabaseConnectable) -> Future<[Model]> {
        return Model.query(on: conn)
            .filter(filter)
            .all()
    }
    
    static public func find(_ id: Model.ID, or error: Error, on conn: DatabaseConnectable) -> Future<Model> {
        return Model.find(id, on: conn)
            .unwrap(or: error)
    }
    
    static public func find(_ id: Model.ID, on conn: DatabaseConnectable) -> Future<Model?> {
        return Model.find(id, on: conn)
    }
}

public protocol KognitaRepositoryDeletable : KognitaRepository {
    /// Deletes a Model object
    ///
    /// - Parameter model: The model to delete
    /// - Parameter user: The used that is deleting the model
    /// - Parameter conn: The database connection
    static func delete(_ model: Model, by user: User?, on conn: DatabaseConnectable) throws -> Future<Void>
}

extension KognitaRepositoryDeletable {
    static public func delete(_ model: Model, by user: User?, on conn: DatabaseConnectable) throws -> Future<Void> {
        guard let user = user,
            user.isCreator else { throw Abort(.forbidden) }
        return model.delete(on: conn)
    }
}

public protocol KognitaModelUpdatable : KognitaCRUDModel {
    func updateValues(with content: Edit.Data) throws
}

public protocol KognitaRepositoryEditable : KognitaRepository where Model : KognitaCRUDModel {
    /// Edit a Model
    ///
    /// - Parameter model: The model to edit
    /// - Parameter content: The data defining the new Model
    /// - Parameter user: The user editing
    /// - Parameter conn: The database connection
    static func edit(_ model: Model, to content: Model.Edit.Data, by user: User, on conn: DatabaseConnectable) throws -> Future<Model.Edit.Response>
}

extension KognitaRepositoryEditable where Model : KognitaModelUpdatable, Model.Edit.Response == Model {
    static public func edit(_ model: Model, to content: Model.Edit.Data, by user: User, on conn: DatabaseConnectable) throws -> Future<Model.Edit.Response> {
                    
        guard user.isCreator else { throw Abort(.forbidden) }
        
        try model.updateValues(with: content)
        return model.save(on: conn)
    }
}

/// A protocol that defines a Model to be used in Kognita
public protocol KognitaPersistenceModel : PostgreSQLModel, Migration {
    
    associatedtype Create where Create : KognitaRequestData
    associatedtype Repository where Repository : KognitaRepository, Repository.Model == Self
    
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
}

public typealias KognitaCRUDRepository = KognitaRepositoryDeletable & KognitaRepositoryEditable

public protocol KognitaCRUDModel : KognitaPersistenceModel where Repository : KognitaRepositoryDeletable, Repository : KognitaRepositoryEditable {
    associatedtype Edit : KognitaRequestData
}

public protocol SoftDeleatableModel : KognitaPersistenceModel where Repository : KognitaRepositoryDeletable {
    
    var deletedAt: Date? { get set }
}

extension SoftDeleatableModel {
    public static var deletedAtKey: WritableKeyPath<Self, Date?>? { return \Self.deletedAt }
}
