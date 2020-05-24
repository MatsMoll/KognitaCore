//
//  DiscussionTask.swift
//  Core
//
//  Created by Eskild Brobak on 25/02/2020.
//

import FluentPostgreSQL
import Vapor

extension TaskDiscussion {
    public final class DatabaseModel: KognitaCRUDModel, Validatable {

        public static var tableName: String = "TaskDiscussion"

        public var id: Int?

        public var userID: User.ID

        public var description: String

        public var taskID: Task.ID

        public var createdAt: Date?

        public var updatedAt: Date?

        init(data: Create.Data, userID: User.ID) throws {
            self.description = data.description
            self.taskID = data.taskID
            self.userID = userID
            try validate()
        }

        func update(with data: Update.Data) throws {
            description = data.description
            try validate()
        }

        public static func prepare(on conn: PostgreSQLConnection) -> EventLoopFuture<Void> {
            PostgreSQLDatabase.create(TaskDiscussion.DatabaseModel.self, on: conn) { builder in

                try addProperties(to: builder)

                builder.reference(from: \.taskID, to: \Task.id, onUpdate: .cascade, onDelete: .cascade)
            }.flatMap {
                PostgreSQLDatabase.update(TaskDiscussion.DatabaseModel.self, on: conn) { builder in
                    builder.deleteField(for: \.userID)
                    builder.field(for: \.userID, type: .int, .default(1))
                    builder.reference(from: \.userID, to: \User.id, onUpdate: .cascade, onDelete: .setDefault)
                }
            }
        }

        public static func validations() throws -> Validations<TaskDiscussion.DatabaseModel> {
            var validations = Validations(TaskDiscussion.DatabaseModel.self)
            try validations.add(\.description, .count(4...))
            try validations.add(\.userID, .range(1...))
            try validations.add(\.taskID, .range(1...))
            return validations
        }
    }

}

//extension TaskDiscussion: ModelParameterRepresentable {}
