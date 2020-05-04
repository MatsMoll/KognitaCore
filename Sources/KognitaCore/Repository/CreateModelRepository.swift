//
//  CreateModelRepository.swift
//  KognitaCore
//
//  Created by Mats Mollestad on 22/12/2019.
//

import FluentPostgreSQL

public protocol CreateModelRepository {
    associatedtype CreateData
    associatedtype CreateResponse

    /// Creates a Model in the repository
    /// - Parameters:
    ///   - content: The content that is needed to create the Model
    ///   - user: The user creating the Model. Is optional as not all Models need a User
    ///   - conn: A object that can create a DatabaseConnection if needed
    static func create(from content: CreateData, by user: User?, on conn: DatabaseConnectable) throws -> EventLoopFuture<CreateResponse>
}
