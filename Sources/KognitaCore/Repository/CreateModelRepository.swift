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

    static func create(from content: CreateData, by user: User?, on conn: DatabaseConnectable) throws -> EventLoopFuture<CreateResponse>
}
