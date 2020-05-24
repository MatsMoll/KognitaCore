import Foundation

/// This is a model that works as a superclass to all submitted answers
/// This is also the type that sould be be referenced to in the database
public final class TaskAnswer: KognitaPersistenceModel {

    public static var tableName: String = "TaskAnswer"

    public var createdAt: Date?

    public var updatedAt: Date?

    public var id: Int?
}
