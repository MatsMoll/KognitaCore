//
//  Request+MetricsFactory.swift
//  KognitaCore
//
//  Created by Mats Mollestad on 21/11/2020.
//

import Vapor
import Metrics

public struct MetricsInstanceFactory {

    var make: ((Request) -> MetricsFactory)?

    public mutating func use(factory: @escaping (Request) -> MetricsFactory) {
        self.make = factory
    }
}

extension Application {
    private struct MetricsFactoryKey: StorageKey {
        typealias Value = MetricsInstanceFactory
    }

    public var metricsFactory: MetricsInstanceFactory {
        get { self.storage[MetricsFactoryKey.self] ?? .init() }
        set { self.storage[MetricsFactoryKey.self] = newValue }
    }
}

extension Request {
    public var metrics: MetricsFactory {
        application.metricsFactory.make!(self)
    }
}
