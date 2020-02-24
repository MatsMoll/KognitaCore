import Vapor
import Foundation
import FluentPostgreSQL

public typealias Job = (Container, DatabaseConnectable) -> Future<Void>

public protocol JobQueueable: Service {
    func scheduleFutureJob(after delay: TimeAmount, job: @escaping Job)
}

final class ProductionJobQueue: JobQueueable {
    private let eventLoop: EventLoop
    private let container: Container

    init(eventLoop: EventLoop, container: Container) {
        self.eventLoop = eventLoop
        self.container = container
    }


    func scheduleFutureJob(after delay: TimeAmount, job: @escaping Job) {
        eventLoop.scheduleTask(in: delay) {
            self.container.requestCachedConnection(to: .psql)
                .flatMap { conn in
                    job(self.container, conn)
            }
        }
    }
}


extension ProductionJobQueue: ServiceType {
    static var serviceSupports: [Any.Type] {
        return [JobQueueable.self]
    }

    static func makeService(for worker: Container) throws -> ProductionJobQueue {
        return ProductionJobQueue(eventLoop: worker.eventLoop, container: worker)
    }
}


public func config(enviroment: Environment, in services: inout Services) {
    services.register(
        DatabaseMigrations.migrationConfig(enviroment: enviroment)
    )
    services.register(ProductionJobQueue.self)
}
