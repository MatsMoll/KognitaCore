//
//  DiscussionTaskRespons.swift
//  KognitaCore
//
//  Created by Eskild Brobak on 25/02/2020.
//

import FluentPostgreSQL
import Vapor

extension TaskDiscussion {
    public enum Pivot {}
}


extension TaskDiscussion.Pivot {

    public final class Response: KognitaPersistenceModel, Validatable {

        public var id: Int?

        public var userID: User.ID

        public var response: String

        public var discussionID: TaskDiscussion.ID

        public var createdAt: Date?

        public var updatedAt: Date?

        init(data: TaskDiscussion.Pivot.Response.Create.Data, userID: User.ID) throws {
            self.response = try data.response.cleanXSS(whitelist: .basicWithImages())
            self.discussionID = data.discussionID
            self.userID = userID
            try validate()
        }

        public static func validations() throws -> Validations<TaskDiscussion.Pivot.Response> {
            var validations = Validations(TaskDiscussion.Pivot.Response.self)
            try validations.add(\.response, .count(4...))
            try validations.add(\.userID, .range(1...))
            try validations.add(\.discussionID, .range(1...))
            return validations
        }
    }
}


extension TaskDiscussion.Pivot.Response {
    public static func prepare(on conn: PostgreSQLConnection) -> EventLoopFuture<Void> {
        PostgreSQLDatabase.create(TaskDiscussion.Pivot.Response.self, on: conn) { builder in
            try addProperties(to: builder)

            builder.reference(from: \.discussionID, to: \TaskDiscussion.id, onUpdate: .cascade, onDelete: .cascade)
            builder.reference(from: \.userID, to: \User.id, onUpdate: .cascade, onDelete: .setDefault)
        }.flatMap {
            PostgreSQLDatabase.update(TaskDiscussion.Pivot.Response.self, on: conn) { builder in
                builder.deleteField(for: \.userID)
                builder.field(for: \.userID, type: .int, .default(1))
            }
        }
    }
}
