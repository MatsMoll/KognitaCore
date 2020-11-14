//
//  Request+repositories.swift
//  KognitaCore
//
//  Created by Mats Mollestad on 14/11/2020.
//

import Vapor

extension Request {

    public func repositories<T>(_ transaction: @escaping (RepositoriesRepresentable) -> EventLoopFuture<T>) -> EventLoopFuture<T> {
        self.application.repositoriesFactory.make!.repositories(req: self, tran: transaction)
    }

    public func repositories<T>(_ transaction: @escaping (RepositoriesRepresentable) throws -> EventLoopFuture<T>) -> EventLoopFuture<T> {
        self.application.repositoriesFactory.make!.repositories(req: self) { repo in
            do {
                return try transaction(repo)
            } catch {
                return self.eventLoop.future(error: error)
            }
        }
    }
}
