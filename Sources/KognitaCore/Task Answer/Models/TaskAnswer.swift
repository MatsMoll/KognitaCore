import Foundation
import FluentKit

/// This is a model that works as a superclass to all submitted answers
/// This is also the type that sould be be referenced to in the database
public final class TaskAnswer: KognitaPersistenceModel {

    public static var tableName: String = "TaskAnswer"

    @Timestamp(key: "createdAt", on: .create)
    public var createdAt: Date?

    @Timestamp(key: "updatedAt", on: .update)
    public var updatedAt: Date?

    @DBID(custom: "id")
    public var id: Int?

    public init() {}
}

extension TaskAnswer {
    enum Migrations {
        struct Create: KognitaModelMigration {
            typealias Model = TaskAnswer

            func build(schema: SchemaBuilder) -> SchemaBuilder {
                schema.defaultTimestamps()
            }
        }
    }
}
