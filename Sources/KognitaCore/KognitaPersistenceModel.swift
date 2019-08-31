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
    
    /// A shared instance of the repo
    static var shared: Self { get }
    
    /// Creates a Model
    ///
    /// - Parameter content: The data defining the model
    /// - Parameter user: The user creating the model
    /// - Parameter conn: The database connection
    func create(from content: Model.Create.Data, by user: User?, on conn: DatabaseConnectable) throws -> Future<Model.Create.Response>
    
    func first(where filter: FilterOperator<PostgreSQLDatabase, Model>, or error: Error, on conn: DatabaseConnectable) -> Future<Model>
    func first(where filter: FilterOperator<PostgreSQLDatabase, Model>, on conn: DatabaseConnectable) -> Future<Model?>
    func all(where filter: FilterOperator<PostgreSQLDatabase, Model>, on conn: DatabaseConnectable) -> Future<[Model]>
    func find(_ id: Model.ID, or error: Error, on conn: DatabaseConnectable) -> Future<Model>
    func find(_ id: Model.ID, on conn: DatabaseConnectable) -> Future<Model?>
}

extension KognitaRepository {
    
    public func first(where filter: FilterOperator<PostgreSQLDatabase, Model>, or error: Error, on conn: DatabaseConnectable) -> Future<Model> {
        return Model.query(on: conn)
            .filter(filter)
            .first()
            .unwrap(or: error)
    }
    
    public func first(where filter: FilterOperator<PostgreSQLDatabase, Model>, on conn: DatabaseConnectable) -> Future<Model?> {
        return Model.query(on: conn)
            .filter(filter)
            .first()
    }
    
    public func all(where filter: FilterOperator<PostgreSQLDatabase, Model>, on conn: DatabaseConnectable) -> Future<[Model]> {
        return Model.query(on: conn)
            .filter(filter)
            .all()
    }
    
    public func find(_ id: Model.ID, or error: Error, on conn: DatabaseConnectable) -> Future<Model> {
        return Model.find(id, on: conn)
            .unwrap(or: error)
    }
    
    public func find(_ id: Model.ID, on conn: DatabaseConnectable) -> Future<Model?> {
        return Model.find(id, on: conn)
    }
}

public protocol KognitaRepositoryDeletable : KognitaRepository {
    /// Deletes a Model object
    ///
    /// - Parameter model: The model to delete
    /// - Parameter user: The used that is deleting the model
    /// - Parameter conn: The database connection
    func delete(_ model: Model, by user: User?, on conn: DatabaseConnectable) throws -> Future<Void>
}

extension KognitaRepositoryDeletable {
    public func delete(_ model: Model, by user: User?, on conn: DatabaseConnectable) throws -> Future<Void> {
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
    func edit(_ model: Model, to content: Model.Edit.Data, by user: User, on conn: DatabaseConnectable) throws -> Future<Model.Edit.Response>
}

extension KognitaRepositoryEditable where Model : KognitaModelUpdatable, Model.Edit.Response == Model {
    public func edit(_ model: Model, to content: Model.Edit.Data, by user: User, on conn: DatabaseConnectable) throws -> Future<Model.Edit.Response> {
                    
        guard user.isCreator else { throw Abort(.forbidden) }
        
        try model.updateValues(with: content)
        return model.save(on: conn)
    }
}

/// A protocol that defines a Model to be used in Kognita
public protocol KognitaPersistenceModel : PostgreSQLModel, Migration {
    
    associatedtype Create where Create : KognitaRequestData
    associatedtype Repository where Repository : KognitaRepository, Repository.Model == Self
    
    /// The repository for the model
    static var repository: Repository { get }
    
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
    
    public static var repository: Repository { return Repository.shared }
    
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
