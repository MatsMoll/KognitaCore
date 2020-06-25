//
//  FlashCardTask+Answer.swift
//  KognitaCore
//
//  Created by Mats Mollestad on 25/10/2019.
//

import Vapor
import FluentKit

/// A submitted answer form a `FlashCardTask`
final class FlashCardAnswer: Model {

    static var schema: String = "FlashCardAnswer"

    @DBID(custom: "id")
    public var id: Int?

    @Parent(key: "taskID")
    public var task: FlashCardTask

    @Field(key: "answer")
    public var answer: String

    init(answerID: TaskAnswer.IDValue, taskID: FlashCardTask.IDValue, answer: String) {
        self.id = answerID
        self.$task.id = taskID
        self.answer = answer
    }

    init() {}
}

extension FlashCardAnswer {
    enum Migrations {}
}

extension FlashCardAnswer.Migrations {
    struct Create: Migration {

        let schema = FlashCardAnswer.schema

        func prepare(on database: Database) -> EventLoopFuture<Void> {
            database.schema(schema)
                .field("id", .uint, .identifier(auto: true), .references(TaskAnswer.schema, .id, onDelete: .cascade, onUpdate: .cascade))
                .field("taskID", .uint, .required, .references(TaskDatabaseModel.schema, .id, onDelete: .cascade, onUpdate: .cascade))
                .field("answer", .string, .required)
                .create()
        }

        func revert(on database: Database) -> EventLoopFuture<Void> {
            database.schema(schema).delete()
        }
    }
}
