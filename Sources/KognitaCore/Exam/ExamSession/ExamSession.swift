//
//  ExamSession.swift
//  KognitaCore
//
//  Created by Mats Mollestad on 06/11/2020.
//

import FluentKit

extension ExamSession {
    final class DatabaseModel: Model {

        static var schema: String = "ExamSession"

        @DBID(custom: "id", generatedBy: .user)
        public var id: Int?

        /// The number of task to complete in the session
        @Field(key: "numberOfTaskGoal")
        public var numberOfTaskGoal: Int

        @Parent(key: "examID")
        public var exam: Exam.DatabaseModel

        @Timestamp(key: "createdAt", on: .create)
        var createdAt: Date?

        @Timestamp(key: "updatedAt", on: .update)
        var updatedAt: Date?

        init(id: TaskSession.IDValue, examID: Exam.ID, numberOfTaskGoal: Int) {
            self.id = id
            self.$exam.id = examID
            self.numberOfTaskGoal = numberOfTaskGoal
        }

        init() {}
    }
}

extension ExamSession.DatabaseModel: ContentConvertable {

    func content() throws -> ExamSession {
        try ExamSession(
            id: requireID(),
            numberOfTaskGoal: numberOfTaskGoal,
            createdAt: createdAt ?? Date()
        )
    }
}

extension ExamSession {
    enum Migrations {

        struct Create: KognitaModelMigration {

            typealias Model = ExamSession.DatabaseModel

            func build(schema: SchemaBuilder) -> SchemaBuilder {
                schema
                    .field("numberOfTaskGoal", .int, .required)
                    .field("examID", .uint, .required, .references(Exam.DatabaseModel.schema, .id, onDelete: .cascade, onUpdate: .cascade))
                    .foreignKey("id", references: TaskSession.schema, .id, onDelete: .cascade, onUpdate: .cascade)
                    .defaultTimestamps()
            }
        }
    }
}
