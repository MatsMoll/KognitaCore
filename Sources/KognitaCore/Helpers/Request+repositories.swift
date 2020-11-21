//
//  Request+repositories.swift
//  KognitaCore
//
//  Created by Mats Mollestad on 14/11/2020.
//

import Vapor
import Metrics

extension Request {

    public func repositories<T>(file: String = #file, function: String = #function, transaction: @escaping (RepositoriesRepresentable) -> EventLoopFuture<T>) -> EventLoopFuture<T> {
        let start = Date()
        return self.application.repositoriesFactory.make!.repositories(req: self, tran: transaction)
            .always { [weak self] result in
                self?.register(result: result, start: start, function: function, file: file)
        }
    }

    public func repositories<T>(file: String = #file, function: String = #function, transaction: @escaping (RepositoriesRepresentable) throws -> EventLoopFuture<T>) -> EventLoopFuture<T> {
        let start = Date()
        return self.application.repositoriesFactory.make!.repositories(req: self) { repo in
            do {
                return try transaction(repo)
            } catch {
                return self.eventLoop.future(error: error)
            }
        }
        .always { [weak self] result in
            self?.register(result: result, start: start, function: function, file: file)
        }
    }

    private func register<T>(result: Result<T, Error>, start: Date, function: String, file: String) {
        switch result {
        case .success:
            let end = Date()
            let duration = metrics.makeTimer(
                label: DatabaseRepositories.metricsTimerLabel,
                dimensions: [
                    ("file", file),
                    ("function", function)
                ]
            )
            duration.recordNanoseconds(Int64(end.timeIntervalSince(start) * 1000))
        case .failure(let error):
            let errorCounter = metrics.makeCounter(
                label: DatabaseRepositories.metricsErrorCounterLabel,
                dimensions: [
                    ("error", error.localizedDescription),
                    ("file", file),
                    ("function", function)
                ]
            )
            errorCounter.increment(by: 1)
        }
    }
}
