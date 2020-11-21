import Vapor
import FluentKit
import Metrics
import Prometheus

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
    if (try? MetricsSystem.prometheus()) == nil {
        MetricsSystem.bootstrap(PrometheusClient())
    }
    app.metricsFactory.use(factory: { _ in MetricsSystem.factory })

//    services.register(RepositoriesRepresentable.self) { (container: Container) in
//        try DatabaseRepositories(conn: container.connectionPool(to: .psql))
//    }
//    services.register(ProductionJobQueue.self)
}
