//
//  MultipleChoiseTask+Answer.swift
//  KognitaCore
//
//  Created by Mats Mollestad on 25/10/2019.
//

import Vapor
import FluentKit

/// A submittet choise in a task
final class MultipleChoiseTaskAnswer: Model, Codable {

    static var schema: String = "MultipleChoiseTaskAnswer"

    @DBID(custom: "id")
    public var id: Int?

    @Parent(key: "choiseID")
    public var choice: MultipleChoiseTaskChoise

    init(answerID: TaskAnswer.IDValue, choiseID: MultipleChoiseTaskChoise.IDValue) {
        self.id = answerID
        self.$choice.id = choiseID
    }

    init() {}
}

extension MultipleChoiseTaskAnswer {
    enum Migrations {}
}

extension MultipleChoiseTaskAnswer.Migrations {
    struct Create: KognitaModelMigration {

        typealias Model = MultipleChoiseTaskAnswer

        func build(schema: SchemaBuilder) -> SchemaBuilder {
            schema.field("choiseID", .uint, .required, .references(MultipleChoiseTaskChoise.schema, .id, onDelete: .cascade, onUpdate: .cascade))
                .foreignKey("id", references: TaskAnswer.schema, .id, onDelete: .cascade, onUpdate: .cascade)
        }
    }
}
