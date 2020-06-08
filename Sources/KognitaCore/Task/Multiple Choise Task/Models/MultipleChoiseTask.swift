//
//  MultipleChoiseTask.swift
//  App
//
//  Created by Mats Mollestad on 07/10/2018.
//

import Vapor
import FluentPostgreSQL

extension MultipleChoiceTask {
    final class DatabaseModel: KognitaCRUDModel {

        public static var tableName: String = "MultipleChoiseTask"

        public var id: Int?

        /// A bool indicating if the user should be able to select one or more choises
        public var isMultipleSelect: Bool

        public var createdAt: Date?

        public var updatedAt: Date?

        public convenience init(isMultipleSelect: Bool, task: Task) throws {
            try self.init(isMultipleSelect: isMultipleSelect,
                          taskID: task.requireID())
        }

        public var actionDescription: String {
            return isMultipleSelect ? "Velg ett eller flere alternativer" : "Velg ett alternativ"
        }

        public init(isMultipleSelect: Bool, taskID: Task.ID) {
            self.isMultipleSelect = isMultipleSelect
            self.id = taskID
        }

        public static func addTableConstraints(to builder: SchemaCreator<MultipleChoiceTask.DatabaseModel>) {
            builder.reference(from: \.id, to: \Task.id, onUpdate: .cascade, onDelete: .cascade)
        }

    }
}

extension MultipleChoiceTask {
    init(task: Task, isMultipleSelect: Bool, choises: [MultipleChoiseTaskChoise]) {
        self.init(
            id: task.id ?? 0,
            subtopicID: task.subtopicID,
            description: task.description,
            question: task.question,
            creatorID: task.creatorID,
            examType: nil,
            examYear: task.examPaperYear,
            isTestable: task.isTestable,
            createdAt: task.createdAt,
            updatedAt: task.updatedAt,
            editedTaskID: task.editedTaskID,
            isMultipleSelect: isMultipleSelect,
            choises: choises.map { MultipleChoiceTaskChoice(id: $0.id ?? 0, choise: $0.choise, isCorrect: $0.isCorrect) }
        )
    }
}

extension MultipleChoiceTask.DatabaseModel {

    /// Fetches the relevant data used to present a task to the user
    ///
    /// - Parameter conn: A connection to the database
    /// - Returns: A `MultipleChoiseTaskContent` object
    /// - Throws: If there is no relation to a `Task` object or a database error
    func content(on conn: DatabaseConnectable) throws -> EventLoopFuture<MultipleChoiceTask> {

        return try choises
            .query(on: conn)
            .all()
            .flatMap { choises in
                Task.find(self.id ?? 0, on: conn)
                    .unwrap(or: Abort(.internalServerError)).map { task in
                        MultipleChoiceTask(
                            task: task,
                            isMultipleSelect: self.isMultipleSelect,
                            choises: choises.shuffled()
                        )
                }
        }
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

extension MultipleChoiceTask.DatabaseModel {

    var choises: Children<MultipleChoiceTask.DatabaseModel, MultipleChoiseTaskChoise> {
        return children(\.taskId)
    }

    var task: Parent<MultipleChoiceTask.DatabaseModel, Task>? {
        return parent(\.id)
    }

    static func filter(on subtopic: Subtopic, in conn: DatabaseConnectable) throws -> EventLoopFuture<[MultipleChoiceTask.DatabaseModel]> {
        return Task.query(on: conn)
            .filter(\.subtopicID == subtopic.id)
            .join(\MultipleChoiceTask.DatabaseModel.id, to: \Task.id)
            .decode(MultipleChoiceTask.DatabaseModel.self)
            .all()
    }

    static func filter(on topic: Topic, in conn: DatabaseConnectable) throws -> EventLoopFuture<[MultipleChoiceTask.DatabaseModel]> {
        return Task.query(on: conn)
            .join(\Subtopic.DatabaseModel.id, to: \Task.subtopicID)
            .filter(\Subtopic.DatabaseModel.topicId == topic.id)
            .join(\MultipleChoiceTask.DatabaseModel.id, to: \Task.id)
            .decode(MultipleChoiceTask.DatabaseModel.self)
            .all()
    }
}

//extension MultipleChoiceTask: ModelParameterRepresentable { }
extension MultipleChoiceTask: Content { }
