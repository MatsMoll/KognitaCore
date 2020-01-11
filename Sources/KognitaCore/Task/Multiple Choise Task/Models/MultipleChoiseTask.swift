//
//  MultipleChoiseTask.swift
//  App
//
//  Created by Mats Mollestad on 07/10/2018.
//

import Vapor
import FluentPostgreSQL

public final class MultipleChoiseTask: KognitaCRUDModel {

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
        return isMultipleSelect ? "Velg et eller flere alternativ" : "Velg et alternativ"
    }

    public init(isMultipleSelect: Bool, taskID: Task.ID) {
        self.isMultipleSelect = isMultipleSelect
        self.id = taskID
    }
    
    public static func addTableConstraints(to builder: SchemaCreator<MultipleChoiseTask>) {
        builder.reference(from: \.id, to: \Task.id, onUpdate: .cascade, onDelete: .cascade)
    }

}

extension MultipleChoiseTask {

    /// Fetches the relevant data used to present a task to the user
    ///
    /// - Parameter conn: A connection to the database
    /// - Returns: A `MultipleChoiseTaskContent` object
    /// - Throws: If there is no relation to a `Task` object or a database error
    func content(on conn: DatabaseConnectable) throws -> Future<MultipleChoiseTask.Data> {

        return try choises
            .query(on: conn)
            .all()
            .flatMap { choises in
                Task.find(self.id ?? 0, on: conn)
                    .unwrap(or: Abort(.internalServerError)).map { task in
                        MultipleChoiseTask.Data(
                            task: task,
                            multipleTask: self,
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


extension MultipleChoiseTask {

    var choises: Children<MultipleChoiseTask, MultipleChoiseTaskChoise> {
        return children(\.taskId)
    }

    var task: Parent<MultipleChoiseTask, Task>? {
        return parent(\.id)
    }

    static func filter(on subtopic: Subtopic, in conn: DatabaseConnectable) throws -> Future<[MultipleChoiseTask]> {
        return try Task.query(on: conn)
            .filter(\.subtopicID == subtopic.requireID())
            .join(\MultipleChoiseTask.id, to: \Task.id)
            .decode(MultipleChoiseTask.self)
            .all()
    }

    static func filter(on topic: Topic, in conn: DatabaseConnectable) throws -> Future<[MultipleChoiseTask]> {
        return try Task.query(on: conn)
            .join(\Subtopic.id, to: \Task.subtopicID)
            .filter(\Subtopic.topicId == topic.requireID())
            .join(\MultipleChoiseTask.id, to: \Task.id)
            .decode(MultipleChoiseTask.self)
            .all()
    }
}

extension MultipleChoiseTask: Parameter { }
extension MultipleChoiseTask: Content { }

