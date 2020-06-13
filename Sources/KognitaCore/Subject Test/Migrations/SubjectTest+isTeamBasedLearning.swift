import Vapor
import FluentPostgreSQL

extension SubjectTest {

    enum Migration {

        struct IsTeamBasedLearning: PostgreSQLMigration {

            static func prepare(on conn: PostgreSQLConnection) -> EventLoopFuture<Void> {
                PostgreSQLDatabase.update(SubjectTest.DatabaseModel.self, on: conn) { builder in
                    builder.field(for: \SubjectTest.DatabaseModel.isTeamBasedLearning, type: .boolean, .default(.literal(.boolean(.true))))
                }
            }

            static func revert(on conn: PostgreSQLConnection) -> EventLoopFuture<Void> {
                PostgreSQLDatabase.update(SubjectTest.DatabaseModel.self, on: conn) { builder in
                    builder.deleteField(for: \.isTeamBasedLearning)
                }
            }
        }
    }
}
