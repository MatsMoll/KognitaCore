import Vapor
import FluentKit

//import Foundation
//
//public protocol JobQueueable: Service {
//    /// Schedule a job in the future
//    /// - Parameters:
//    ///   - delay: The dalay of the job
//    ///   - job: The job to execute
//    func scheduleFutureJob(after delay: TimeAmount, job: @escaping (Container, DatabaseConnectable) throws -> EventLoopFuture<Void>)
//}
//
//final class ProductionJobQueue: JobQueueable {
//    private let eventLoop: EventLoop
//    private let container: Container
//
//    init(eventLoop: EventLoop, container: Container) {
//        self.eventLoop = eventLoop
//        self.container = container
//    }
//
//    func scheduleFutureJob(after delay: TimeAmount, job: @escaping (Container, DatabaseConnectable) throws -> EventLoopFuture<Void>) {
//        eventLoop.scheduleTask(in: delay) {
//            self.container.requestCachedConnection(to: .psql)
//                .flatMap { conn in
//                    try job(self.container, conn)
//            }
//        }
//    }
//}
//
//extension ProductionJobQueue: ServiceType {
//    static var serviceSupports: [Any.Type] {
//        return [JobQueueable.self]
//    }
//
//    static func makeService(for worker: Container) throws -> ProductionJobQueue {
//        return ProductionJobQueue(eventLoop: worker.eventLoop, container: worker)
//    }
//}
//

struct DatabaseRepositorieFactory: AsyncRepositoriesFactory {
    func repositories<T>(req: Request, tran: @escaping (RepositoriesRepresentable) -> EventLoopFuture<T>) -> EventLoopFuture<T> {
        repositories(database: req.db, password: req.password, logger: req.logger, tran: tran)
    }

    func repositories<T>(app: Application, tran: @escaping (RepositoriesRepresentable) -> EventLoopFuture<T>) -> EventLoopFuture<T> {
        repositories(database: app.db, password: app.password, logger: app.logger, tran: tran)
    }

    private func repositories<T>(database: Database, password: PasswordHasher, logger: Logger, tran: @escaping (RepositoriesRepresentable) -> EventLoopFuture<T>) -> EventLoopFuture<T> {
        database.transaction { database in
            tran(DatabaseRepositories(database: database, password: password, logger: logger))
        }
    }
}

public func config(app: Application) {
    DatabaseMigrations.migrationConfig(app)
    app.repositoriesFactory.use(DatabaseRepositorieFactory())
//    services.register(RepositoriesRepresentable.self) { (container: Container) in
//        try DatabaseRepositories(conn: container.connectionPool(to: .psql))
//    }
//    services.register(ProductionJobQueue.self)
}
