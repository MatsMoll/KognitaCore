//
//  MultipleChoiseTask.swift
//  App
//
//  Created by Mats Mollestad on 07/10/2018.
//

import Vapor
import FluentPostgreSQL

public struct MultipleChoiseTaskChoiseContent: Content {

    public let choise: String

    public let isCorrect: Bool
}

public struct MultipleChoiseTaskCreationContent: Content, TaskCreationContentable {

    public let subtopicId: Topic.ID

    public let description: String?

    public let question: String

    public let solution: String?

    public let isMultipleSelect: Bool

    public let examPaperSemester: Task.ExamSemester?

    public let examPaperYear: Int?

    public let isExaminable: Bool

    public let choises: [MultipleChoiseTaskChoiseContent]

    public func validate() throws {
        try (self as TaskCreationContentable).validate()
        let numberOfCorrectChoises = choises.filter { $0.isCorrect }
        guard numberOfCorrectChoises.count > 0 else {
            throw Abort(.badRequest)
        }
        if !isMultipleSelect {
            guard numberOfCorrectChoises.count == 1 else {
                throw Abort(.badRequest)
            }
        }
    }
}

public final class MultipleChoiseTask: PostgreSQLModel {

    public var id: Int?

    /// A bool indicating if the user should be able to select one or more choises
    public var isMultipleSelect: Bool

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

    /// Creates and saves a multiple choise task
    ///
    /// - Parameters:
    ///     - content:      The content to assign the task
    ///     - user:         The user creating the task
    ///     - connection:   A connection to the database
    ///
    /// - Returns:          The task id of the created task
    static func create(
        with content: MultipleChoiseTaskCreationContent,
        for subtopic: Subtopic,
        user: User,
        connection: DatabaseConnectable
    ) throws -> Future<MultipleChoiseTask> {

        return try Task(content: content, subtopic: subtopic, creator: user)
            .create(on: connection)
            .flatMap { (task) in
                try MultipleChoiseTask(
                    isMultipleSelect: content.isMultipleSelect,
                    task: task)
                    .create(on: connection)
            } .flatMap { (task) in
                try content.choises.map { choise in
                    try MultipleChoiseTaskChoise(content: choise, task: task)
                        .create(on: connection)
                }
                    .flatten(on: connection)
                    .transform(to: task)
            }
    }

    /// Fetches the relevant data used to present a task to the user
    ///
    /// - Parameter conn: A connection to the database
    /// - Returns: A `MultipleChoiseTaskContent` object
    /// - Throws: If there is no relation to a `Task` object or a database error
    func content(on conn: DatabaseConnectable) throws -> Future<MultipleChoiseTaskContent> {

        return try choises
            .query(on: conn)
            .all().flatMap { choises in
                Task.find(self.id ?? 0, on: conn)
                    .unwrap(or: Abort(.internalServerError)).map { task in
                        MultipleChoiseTaskContent(
                            task: task,
                            multipleTask: self,
                            choises: choises.shuffled()
                        )
                }
        }
    }
}

extension MultipleChoiseTask {
    
    func evaluateAnswer(for submit: MultipleChoiseTaskSubmit, on connection: DatabaseConnectable) throws -> Future<PracticeSessionResult<[MultipleChoiseTaskChoiseResult]>> {
        
        return try MultipleChoiseTaskRepository.shared
            .evaluate(submit, for: self, on: connection)
    }
}

extension MultipleChoiseTask {

    var choises: Children<MultipleChoiseTask, MultipleChoiseTaskChoise> {
        return children(\.taskId)
    }

    var task: Parent<MultipleChoiseTask, Task>? {
        return parent(\.id)
    }

//    func joinTask(on conn: DatabaseConnectable) throws -> Future<String> {
//        guard let task = task else {
//            throw Abort(.internalServerError)
//        }
//        return conn.future().transform(to: "f")
//        return task.get(on: conn).map { (task) in
//            return try JoinedMultipleChoiseTask(task: task, multipleChoise: self, choises: [])
//        }
//    }

    static func filter(on subtopic: Subtopic, in conn: DatabaseConnectable) throws -> Future<[MultipleChoiseTask]> {
        return try Task.query(on: conn)
            .filter(\.subtopicId == subtopic.requireID())
            .join(\MultipleChoiseTask.id, to: \Task.id)
            .decode(MultipleChoiseTask.self)
            .all()
    }

    static func filter(on topic: Topic, in conn: DatabaseConnectable) throws -> Future<[MultipleChoiseTask]> {
        return try Task.query(on: conn)
            .join(\Subtopic.id, to: \Task.subtopicId)
            .filter(\Subtopic.topicId == topic.requireID())
            .join(\MultipleChoiseTask.id, to: \Task.id)
            .decode(MultipleChoiseTask.self)
            .all()
    }
}

extension MultipleChoiseTask: Migration {
    public static func prepare(on conn: PostgreSQLConnection) -> Future<Void> {
        return PostgreSQLDatabase.create(MultipleChoiseTask.self, on: conn) { builder in
            try addProperties(to: builder)
            builder.reference(from: \.id, to: \Task.id, onUpdate: .cascade, onDelete: .cascade)
        }
    }

    public static func revert(on connection: PostgreSQLConnection) -> Future<Void> {
        return PostgreSQLDatabase.delete(MultipleChoiseTask.self, on: connection)
    }
}

extension MultipleChoiseTask: Parameter { }

extension MultipleChoiseTask: Content { }
