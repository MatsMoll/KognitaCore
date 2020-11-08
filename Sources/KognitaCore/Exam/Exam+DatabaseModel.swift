//
//  Exam+DatabaseModel.swift
//  KognitaCore
//
//  Created by Mats Mollestad on 05/11/2020.
//

import Foundation
import FluentKit

extension Exam {
    final class DatabaseModel: KognitaPersistenceModel {

        static var tableName: String = "Exam"

        @DBID(custom: "id")
        var id: Int?

        @Field(key: "year")
        var year: Int

        @Field(key: "type")
        var type: ExamType

        @Parent(key: "subjectID")
        var subject: Subject.DatabaseModel

        @Timestamp(key: "createdAt", on: .create)
        var createdAt: Date?

        @Timestamp(key: "updatedAt", on: .update)
        var updatedAt: Date?

        @Children(for: \TaskDatabaseModel.$exam)
        var tasks: [TaskDatabaseModel]

        init() {}

        init(content: Exam.Create.Data) {
            self.year = content.year
            self.type = content.type
            self.$subject.id = content.subjectID
            self.createdAt = nil
            self.updatedAt = nil
        }

        func update(with content: Exam.Create.Data) {
            self.year = content.year
            self.type = content.type
            self.$subject.id = content.subjectID
        }
    }
}

extension Exam.DatabaseModel: ContentConvertable {

    func content() throws -> Exam {
        try Exam(
            id: requireID(),
            subjectID: $subject.id,
            type: type,
            year: year,
            createdAt: createdAt ?? Date(),
            updatedAt: updatedAt ?? Date()
        )
    }
}

extension Exam {
    enum Migrations {
        struct Create: KognitaModelMigration {

            typealias Model = Exam.DatabaseModel

            func build(schema: SchemaBuilder) -> SchemaBuilder {
                schema
                    .field("type", .string, .required)
                    .field("year", .int, .required)
                    .field("subjectID", .uint, .required, .references(Subject.DatabaseModel.schema, .id, onDelete: .cascade, onUpdate: .cascade))
                    .unique(on: "year", "type", "subjectID")
                    .defaultTimestamps()
            }
        }
    }
}
