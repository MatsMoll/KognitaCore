//
//  File.swift
//  
//
//  Created by Mats Mollestad on 20/12/2020.
//

import Foundation
import FluentKit

extension User.FeideSubject {
    final class DatabaseModel: Model {

        static let schema: String = "User.FeideSubject"

        @DBID(custom: "id")
        var id: Int?

        @Field(key: "groupID")
        var groupID: String

        @Field(key: "code")
        var code: String

        @Field(key: "name")
        var name: String

        @Parent(key: "userID")
        var user: User.DatabaseModel

        @OptionalParent(key: "subjectID")
        var subject: Subject.DatabaseModel?

        @Field(key: "activeUntil")
        var activeUntil: Date?

        @Field(key: "wasViewedAt")
        var wasViewedAt: Date?

        @Field(key: "role")
        var role: String

        init() {}

        init(subject: Feide.Subject, code: String, userID: User.ID, subjectID: Subject.ID?) {
            self.groupID = subject.id
            self.$user.id = userID
            self.$subject.id = subjectID
            self.code = code
            self.name = subject.displayName
            self.role = subject.membership?.displayName ?? "unknown"
            self.activeUntil = subject.membership?.notActiveAfter
            self.wasViewedAt = nil
        }
    }
}

extension User.FeideSubject.DatabaseModel: ContentConvertable {

    func content() throws -> User.FeideSubject {
        try User.FeideSubject(
            id: requireID(),
            groupID: groupID,
            userID: $user.id,
            subjectID: $subject.id,
            code: code,
            name: name,
            activeUntil: activeUntil,
            wasViewedAt: wasViewedAt,
            role: role
        )
    }
}

extension User.FeideSubject {
    enum Migrations {
        struct Create: Migration {

            func prepare(on database: Database) -> EventLoopFuture<Void> {
                database.schema(User.FeideSubject.DatabaseModel.schema)
                    .field("id", .uint, .identifier(auto: true))
                    .field("groupID", .string, .required)
                    .field("code", .string, .required)
                    .field("name", .string, .required)
                    .field("userID", .uint, .required, .references(User.DatabaseModel.schema, .id, onDelete: .cascade, onUpdate: .cascade))
                    .field("activeUntil", .datetime)
                    .field("subjectID", .uint, .references(Subject.DatabaseModel.schema, .id, onDelete: .cascade, onUpdate: .cascade))
                    .field("wasViewedAt", .datetime)
                    .field("role", .string, .required)
                    .create()
            }

            func revert(on database: Database) -> EventLoopFuture<Void> {
                database.schema(User.FeideSubject.DatabaseModel.schema).delete()
            }
        }
    }
}
