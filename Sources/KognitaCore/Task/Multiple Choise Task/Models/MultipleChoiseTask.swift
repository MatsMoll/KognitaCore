//
//  MultipleChoiseTask.swift
//  App
//
//  Created by Mats Mollestad on 07/10/2018.
//

import Vapor
import FluentKit

extension MultipleChoiceTask {
    final class DatabaseModel: KognitaCRUDModel {

        public static var tableName: String = "MultipleChoiseTask"

        @DBID(custom: "id", generatedBy: .user)
        public var id: Int?

        /// A bool indicating if the user should be able to select one or more choises
        @Field(key: "isMultipleSelect")
        public var isMultipleSelect: Bool

        @Timestamp(key: "createdAt", on: .create)
        public var createdAt: Date?

        @Timestamp(key: "updatedAt", on: .update)
        public var updatedAt: Date?

        @Children(for: \.$task)
        var choices: [MultipleChoiseTaskChoise]

        public convenience init(isMultipleSelect: Bool, task: TaskDatabaseModel) throws {
            try self.init(isMultipleSelect: isMultipleSelect,
                          taskID: task.requireID())
        }

        init() {}

        public var actionDescription: String {
            return isMultipleSelect ? "Velg ett eller flere alternativer" : "Velg ett alternativ"
        }

        public init(isMultipleSelect: Bool, taskID: Task.ID) {
            self.isMultipleSelect = isMultipleSelect
            self.id = taskID
        }

        func update(with content: MultipleChoiceTask.Update.Data) -> DatabaseModel {
            self.isMultipleSelect = content.isMultipleSelect
            return self
        }
    }
}

extension MultipleChoiceTask {
    enum Migrations {
        struct Create: KognitaModelMigration {
            typealias Model = MultipleChoiceTask.DatabaseModel

            func build(schema: SchemaBuilder) -> SchemaBuilder { schema }

            func prepare(on database: Database) -> EventLoopFuture<Void> {
                database.schema(MultipleChoiceTask.DatabaseModel.schema)
                    .field("id", .uint, .identifier(auto: false))
                    .field("isMultipleSelect", .bool, .required)
                    .defaultTimestamps()
                    .foreignKey("id", references: TaskDatabaseModel.schema, .id, onDelete: .cascade, onUpdate: .cascade)
                    .create()
            }
        }
    }
}

extension MultipleChoiceTask {
    init(task: TaskDatabaseModel, isMultipleSelect: Bool, choises: [MultipleChoiseTaskChoise]) {
        self.init(
            id: task.id ?? 0,
            subtopicID: task.$subtopic.id,
            description: task.description,
            question: task.question,
            creatorID: task.$creator.id,
            examType: nil,
            examYear: task.examPaperYear,
            isTestable: task.isTestable,
            createdAt: task.createdAt,
            updatedAt: task.updatedAt,
            deletedAt: task.deletedAt,
            editedTaskID: nil,
            isMultipleSelect: isMultipleSelect,
            choises: choises.map { MultipleChoiceTaskChoice(id: $0.id ?? 0, choice: $0.choice, isCorrect: $0.isCorrect) }
        )
    }
}

extension MultipleChoiceTask.DatabaseModel {

    /// Fetches the relevant data used to present a task to the user
    ///
    /// - Parameter conn: A connection to the database
    /// - Returns: A `MultipleChoiseTaskContent` object
    /// - Throws: If there is no relation to a `Task` object or a database error
    func content(task: TaskDatabaseModel, choices: [MultipleChoiseTaskChoise]) throws -> MultipleChoiceTask {
        return MultipleChoiceTask(
            task: task,
            isMultipleSelect: isMultipleSelect,
            choises: choices.shuffled()
        )
    }

    /// Returns the next multiple choise task if it exists
    ///
    /// - Parameter conn: The database connection
    /// - Returns: The multiple choise task
    /// - Throws: If there is no task relation for some reason
//    func next(on conn: DatabaseConnectable) throws -> Future<Task?> {
//        guard let task = task else {
//            throw Abort(.internalServerError, reason: "Missing Task.id referance")
//        }
//        return task.get(on: conn).flatMap { (task) in
//            Task.query(on: conn)
//                .join(\Subtopic.id, to: \Task.subtopicId)
//                .filter(\.topicId == task.topicId)
//                .filter(\.id > task.id)
//                .first()
//        }
//    }
}

//extension MultipleChoiceTask: ModelParameterRepresentable { }
extension MultipleChoiceTask: Content { }
