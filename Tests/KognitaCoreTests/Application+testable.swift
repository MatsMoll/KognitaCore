import Vapor
@testable import KognitaCore
import PostgresKit

extension Application {

    static func testable(envArgs: [String]? = nil) throws -> Application {

        let app = Application(.testing)
        KognitaCore.config(app: app)
        DatabaseMigrations.setupTables(app.migrations)
        setupDatabase(for: app)
        app.logger.logLevel = .debug
        return app
    }
}

struct EmptyContent: Content {}

private func setupDatabase(for app: Application) {

    // Configure a PostgreSQL database

    let hostname = Environment.get("DATABASE_HOSTNAME") ?? "localhost"
    let username = Environment.get("DATABASE_USER") ?? "matsmollestad"
    let databaseName = Environment.get("DATABASE_DB") ?? "testing"
    let databasePort = 5432
    let password = Environment.get("DATABASE_PASSWORD") ?? nil
    let databaseConfig = PostgresConfiguration(
        hostname: hostname,
        port: databasePort,
        username: username,
        password: password,
        database: databaseName
    )

    app.databases.use(.postgres(configuration: databaseConfig, maxConnectionsPerEventLoop: 1), as: .psql)

    // Register the configured PostgreSQL database to the database config.
}
