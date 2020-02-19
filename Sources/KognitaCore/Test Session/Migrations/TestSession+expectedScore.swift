import Vapor
import FluentPostgreSQL

extension TestSession {
    enum Migration {}
}

extension TestSession.Migration {
    struct ExpectedScore: PostgreSQLMigration {

        static func prepare(on conn: PostgreSQLConnection) -> EventLoopFuture<Void> {
            PostgreSQLDatabase.update(TestSession.self, on: conn) { builder in
                builder.field(for: \TestSession.expectedScore)
            }
        }

        static func revert(on conn: PostgreSQLConnection) -> EventLoopFuture<Void> {
            PostgreSQLDatabase.update(TestSession.self, on: conn) { builder in
                builder.deleteField(for: \TestSession.expectedScore)
            }
        }
    }
}
