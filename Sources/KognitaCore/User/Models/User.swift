import Vapor
import FluentKit
import Fluent
import SQLKit

extension User {

    /// A registered user, capable of owning todo items.
    final class DatabaseModel: KognitaCRUDModel {

        init() { }

        public static var tableName: String = "User"

        /// User's unique identifier.
        /// Can be `nil` if the user has not been saved yet.
        @DBID(custom: "id")
        public var id: Int?

        /// The name the user want to go by
        @Field(key: "username")
        public var username: String

        /// User's email address.
        @Field(key: "email")
        public private(set) var email: String

        /// The uri if a picture if provided
        @Field(key: "pictureUrl")
        var pictureUrl: String?

        /// The role of the User
        @Field(key: "isAdmin")
        public private(set) var isAdmin: Bool

        /// If the user has verified the user email
        @Field(key: "isEmailVerified")
        public var isEmailVerified: Bool

        /// Can be `nil` if the user has not been saved yet.
        @Timestamp(key: "createdAt", on: .create)
        public var createdAt: Date?

        /// Can be `nil` if the user has not been saved yet.
        @Timestamp(key: "updatedAt", on: .update)
        public var updatedAt: Date?

        /// Date of last date visiting the task discussions
        @Field(key: "viewedNotificationsAt")
        public var viewedNotificationsAt: Date?

        /// A token used to activate other users
    //    public var loseAccessDate: Date?

    //    public static var deletedAtKey: TimestampKey? = \.loseAccessDate

        /// Creates a new `User`.
        init(id: Int? = nil, username: String, email: String, pictureUrl: String?, isAdmin: Bool = false, isEmailVerified: Bool = false) {
            self.id = id
            self.username = username
            self.email = email.lowercased()
            self.pictureUrl = pictureUrl
            self.isAdmin = isAdmin
            self.isEmailVerified = isEmailVerified
        }
    }
}

extension User.DatabaseModel: ContentConvertable {
    func content() throws -> User {
        try .init(
            id: requireID(),
            username: username,
            email: email,
            registrationDate: createdAt ?? .now,
            isAdmin: isAdmin,
            isEmailVerified: isEmailVerified,
            pictureUrl: pictureUrl
        )
    }
}

extension User {
    enum Migrations {}
}

extension User.Migrations {
    struct Create: KognitaModelMigration {

        typealias Model = User.DatabaseModel

        func build(schema: SchemaBuilder) -> SchemaBuilder {
            schema.field("username", .string, .required)
                .field("email", .string, .required)
                .field("isAdmin", .bool, .required)
                .field("isEmailVerified", .bool, .required)
                .field("viewedNotificationsAt", .datetime)
                .defaultTimestamps()
                .unique(on: "email")
                .unique(on: "username")
                .field("pictureUrl", .string)
        }
    }

    struct FeideSupport: Migration {

        struct PasswordHashQuery: Codable {
            let id: User.ID
            let passwordHash: String
        }

        let createFeideUserMigration = FeideUser.Migrations.Create()
        let createKognitaUserMigration = KognitaUser.Migrations.Create()

        func prepare(on database: Database) -> EventLoopFuture<Void> {
            createFeideUserMigration.prepare(on: database)
                .flatMap {
                    createKognitaUserMigration.prepare(on: database)
                }.flatMap {

                    guard let sql = database as? SQLDatabase else {
                        return database.eventLoop.future(error: Abort(.internalServerError, reason: "Expected SQL Database"))
                    }

                    return sql.select()
                        .column("passwordHash")
                        .column("id")
                        .from(User.DatabaseModel.schema)
                        .where("passwordHash", .isNot, SQLLiteral.null)
                        .all(decoding: PasswordHashQuery.self)
                        .flatMap { passwords in
                            passwords.map { KognitaUser(id: $0.id, passwordHash: $0.passwordHash).create(on: database) }
                                .flatten(on: database.eventLoop)
                        }
                }.flatMap {
                    database.schema(User.DatabaseModel.schema)
                        .field("pictureUrl", .string)
                        .deleteField("passwordHash")
                        .update()
                }
        }

        func revert(on database: Database) -> EventLoopFuture<Void> {

            return database.eventLoop.future(error: Abort(.notImplemented, reason: "Need to set the old passwordHash"))

//            return database.schema(User.DatabaseModel.schema)
//                .deleteField("pictureUrl")
//                .field("passwordHash", .string)
//                .update()
//                .flatMap {
//                    KognitaUser.query(on: database)
//                        .join(superclass: User.DatabaseModel.self, with: KognitaUser.self)
//                        .all(KognitaUser.self, User.DatabaseModel.self)
//                        .flatMap {
//
//                        }
//                }
        }
    }
}

public struct BasicUserAuthenticator: BasicAuthenticator {

    public func authenticate(basic: BasicAuthorization, for request: Request) -> EventLoopFuture<Void> {
        request.repositories { repositories in
            repositories
                .userRepository
                .verify(email: basic.username, with: basic.password)
                .map { user in
                    if let user = user {
                        request.auth.login(user)
                    }
            }
        }
    }
}

public struct BearerUserAuthenticator: BearerAuthenticator {

    public func authenticate(bearer: BearerAuthorization, for request: Request) -> EventLoopFuture<Void> {
        request.repositories { repositories in
            repositories.userRepository
                .user(with: bearer.token)
                .map { user in
                    if let user = user {
                        request.auth.login(user)
                    }
            }
        }
    }
}

extension User: SessionAuthenticatable {
    public var sessionID: User.ID { id }
}

public struct SessionUserAuthenticator: SessionAuthenticator {

    public typealias User = KognitaModels.User

    public func authenticate(sessionID: User.ID, for request: Request) -> EventLoopFuture<Void> {
        User.DatabaseModel.find(sessionID, on: request.db)
            .map { user in
                if let user = user {
                    do {
                        try request.auth.login(user.content())
                    } catch {
                        request.logger.info("Error when converting DB model: \(error)")
                    }
                }
        }
    }
}

extension User {
    public static func basicAuthMiddleware() -> BasicUserAuthenticator { BasicUserAuthenticator() }
    public static func sessionAuthMiddleware() -> SessionUserAuthenticator { SessionUserAuthenticator() }
    public static func bearerAuthMiddleware() -> BearerUserAuthenticator { BearerUserAuthenticator() }
}

/// Allows `User` to be used as a dynamic parameter in route definitions.
//extension User: ModelParameterRepresentable { }

//extension User {
//    struct UnknownUserMigration: PostgreSQLMigration {
//        static func prepare(on conn: PostgreSQLConnection) -> EventLoopFuture<Void> {
//            return User.DatabaseModel(
//                id: nil,
//                username: "Unknown",
//                email: "unknown@kognita.no",
//                passwordHash: "$2b$12$w8PoPj1yhROCdkAc2JjUJefWX91RztazdWo.D5kQhSdY.eSrT3wD6"
//            )
//                .create(on: conn)
//                .transform(to: ())
//        }
//
//        static func revert(on conn: PostgreSQLConnection) -> EventLoopFuture<Void> {
//            conn.future()
//        }
//    }
//}

//extension User {
//    struct ViewedNotificationAtMigration: PostgreSQLMigration {
//
//        static func revert(on conn: PostgreSQLConnection) -> EventLoopFuture<Void> {
//            conn.future()
//        }
//
//        static func prepare(on conn: PostgreSQLConnection) -> EventLoopFuture<Void> {
//            PostgreSQLDatabase.update(User.DatabaseModel.self, on: conn) { builder in
//                builder.field(for: \User.DatabaseModel.viewedNotificationsAt)
//            }
//        }
//    }
//}
