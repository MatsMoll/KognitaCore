//
//  MultipleChoiseTask.swift
//  App
//
//  Created by Mats Mollestad on 07/10/2018.
//

import Vapor
import FluentPostgreSQL

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
        with content: MultipleChoiseTask.Create.Data,
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
    func content(on conn: DatabaseConnectable) throws -> Future<MultipleChoiseTask.Data> {

        return try choises
            .query(on: conn)
            .all().flatMap { choises in
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

    /// Evaluate the answer submitted, and returns the result
    ///
    /// - Parameters:
    ///   - submit: The submitted answers
    ///   - conn: A connection to the database
    /// - Returns: The results
    /// - Throws: If there was an error with the database query
    func evaluateAnswer(_ submit: MultipleChoiseTaskSubmit,
                        on conn: DatabaseConnectable) throws -> Future<PracticeSessionResult<[MultipleChoiseTaskChoiseResult]>> {

        return try choises
            .query(on: conn)
            .filter(\.isCorrect == true)
            .all()
            .map { (correctChoises) in

                var numberOfCorrect = 0
                var numberOfIncorrect = 0
                var missingAnswers = correctChoises
                var results = [MultipleChoiseTaskChoiseResult]()

                for choise in submit.choises {
                    if let index = missingAnswers.firstIndex(where: { $0.id == choise }) {
                        numberOfCorrect += 1
                        missingAnswers.remove(at: index)
                        results.append(MultipleChoiseTaskChoiseResult(id: choise, isCorrect: true))
                    } else {
                        numberOfIncorrect += 1
                        results.append(MultipleChoiseTaskChoiseResult(id: choise, isCorrect: false))
                    }
                }
                try results += missingAnswers.map {
                    try MultipleChoiseTaskChoiseResult(id: $0.requireID(), isCorrect: true)
                }

                let forgivingScore = Double(numberOfCorrect) / Double(correctChoises.count)
                let unforgivingScore = Double(numberOfCorrect - numberOfIncorrect) / Double(correctChoises.count)

                return PracticeSessionResult(
                    result: results,
                    unforgivingScore: unforgivingScore,
                    forgivingScore: forgivingScore,
                    progress: 0
                )
        }
    }
}

extension MultipleChoiseTask {

    func practiceResult(for submit: MultipleChoiseTaskSubmit, on connection: DatabaseConnectable) throws -> Future<PracticeSessionResult<[MultipleChoiseTaskChoiseResult]>> {
        return try evaluateAnswer(submit, on: connection)
    }
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
