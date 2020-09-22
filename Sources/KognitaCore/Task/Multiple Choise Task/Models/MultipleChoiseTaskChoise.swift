//
//  MultipleChoiseTaskChoise.swift
//  App
//
//  Created by Mats Mollestad on 07/10/2018.
//

import Vapor
import FluentKit

final class MultipleChoiseTaskChoise: Model {

    public static var schema: String = "MultipleChoiseTaskChoise"

    @DBID(custom: "id")
    public var id: Int?

    /// The choise description
    @Field(key: "choise")
    public var choice: String

    /// A bool indication if it is correct or false
    @Field(key: "isCorrect")
    public var isCorrect: Bool

    /// The id of the taks this choise relates to
    @Parent(key: "taskId")
    internal var task: MultipleChoiceTask.DatabaseModel

    public init(choise: String, isCorrect: Bool, taskId: MultipleChoiceTask.ID) {
        self.choice = choise
        self.isCorrect = isCorrect
        self.$task.id = taskId
    }

    public init(content: MultipleChoiceTaskChoice.Create.Data, taskID: MultipleChoiceTask.ID) {
        self.$task.id = taskID
        self.isCorrect = content.isCorrect
        self.choice = (try? content.choice.cleanXSS(whitelist: .basicWithImages())) ?? content.choice
    }

    public init() {}
}

extension MultipleChoiseTaskChoise {
    enum Migrations {}
}

extension MultipleChoiseTaskChoise.Migrations {
    struct Create: KognitaModelMigration {

        typealias Model = MultipleChoiseTaskChoise

        func build(schema: SchemaBuilder) -> SchemaBuilder {
            schema.field("choise", .string, .required)
                .field("isCorrect", .bool, .required)
                .field("taskId", .uint, .required, .references(MultipleChoiceTask.DatabaseModel.schema, .id, onDelete: .cascade, onUpdate: .cascade))
        }
    }
}

extension MultipleChoiseTaskChoise: Content { }

extension MultipleChoiseTaskChoise: ContentConvertable {
    func content() throws -> MultipleChoiceTaskChoice {
        try MultipleChoiceTaskChoice(id: requireID(), choice: choice, isCorrect: isCorrect)
    }
}
