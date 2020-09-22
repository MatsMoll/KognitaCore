import Vapor
import FluentKit

extension SubjectTest {

    enum Migrations {

        struct Create: KognitaModelMigration {
            typealias Model = SubjectTest.DatabaseModel

            func build(schema: SchemaBuilder) -> SchemaBuilder {
                schema.field("subjectID", .uint, .required, .references(Subject.DatabaseModel.schema, .id, onDelete: .cascade, onUpdate: .cascade))
                    .field("duration", .double, .required)
                    .field("openedAt", .datetime)
                    .field("endedAt", .datetime)
                    .field("scheduledAt", .datetime, .required)
                    .field("password", .string)
                    .field("title", .string, .required)
                    .field("isTeamBasedLearning", .bool, .required)
                    .defaultTimestamps()
            }
        }

//        struct IsTeamBasedLearning: PostgreSQLMigration {
//
//            static func prepare(on conn: PostgreSQLConnection) -> EventLoopFuture<Void> {
//                PostgreSQLDatabase.update(SubjectTest.DatabaseModel.self, on: conn) { builder in
//                    builder.field(for: \SubjectTest.DatabaseModel.isTeamBasedLearning, type: .boolean, .default(.literal(.boolean(.true))))
//                }
//            }
//
//            static func revert(on conn: PostgreSQLConnection) -> EventLoopFuture<Void> {
//                PostgreSQLDatabase.update(SubjectTest.DatabaseModel.self, on: conn) { builder in
//                    builder.deleteField(for: \.isTeamBasedLearning)
//                }
//            }
//        }
    }
}
