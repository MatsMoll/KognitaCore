import Authentication
import FluentPostgreSQL
import Vapor

public protocol UserContent {
    var userId: Int { get }
    var username: String { get }
    var email: String { get }
}

extension User {

    /// A registered user, capable of owning todo items.
    final class DatabaseModel: KognitaCRUDModel {

        public static var tableName: String = "User"

        /// User's unique identifier.
        /// Can be `nil` if the user has not been saved yet.
        public var id: Int?

        public var userId: Int { id ?? 0 }

        /// The name the user want to go by
        public var username: String

        /// User's email address.
        public private(set) var email: String

        /// BCrypt hash of the user's password.
        public private(set) var passwordHash: String

        /// The role of the User
        public private(set) var isAdmin: Bool

        /// If the user has verified the user email
        public var isEmailVerified: Bool

        /// Can be `nil` if the user has not been saved yet.
        public var createdAt: Date?

        /// Can be `nil` if the user has not been saved yet.
        public var updatedAt: Date?

        /// Date of last date visiting the task discussions
        public var viewedNotificationsAt: Date?

        /// A token used to activate other users
    //    public var loseAccessDate: Date?

    //    public static var deletedAtKey: TimestampKey? = \.loseAccessDate

        /// Creates a new `User`.
        init(id: Int? = nil, username: String, email: String, passwordHash: String, isAdmin: Bool = false, isEmailVerified: Bool = false) {
            self.id = id
            self.username = username
            self.email = email.lowercased()
            self.passwordHash = passwordHash
            self.isAdmin = isAdmin
            self.isEmailVerified = isEmailVerified
        }

        public static func addTableConstraints(to builder: SchemaCreator<User.DatabaseModel>) {
            builder.unique(on: \.email)
            builder.unique(on: \.username)
        }

        public func update(password: String) throws {
            passwordHash = try BCrypt.hash(password)
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
            isEmailVerified: isEmailVerified
        )
    }
}

/// Allows users to be verified by basic / password auth middleware.
extension User.DatabaseModel: PasswordAuthenticatable {
    /// See `PasswordAuthenticatable`.
    public static var usernameKey: WritableKeyPath<User.DatabaseModel, String> = \.email

    /// See `PasswordAuthenticatable`.
    public static var passwordKey: WritableKeyPath<User.DatabaseModel, String> = \.passwordHash
}

/// Allows users to be verified by bearer / token auth middleware.
extension User.DatabaseModel: TokenAuthenticatable {

    /// See `TokenAuthenticatable`.
    public typealias TokenType = User.Login.Token.DatabaseModel
}

extension User: PasswordAuthenticatable {
    public static func authenticate(username: String, password: String, using verifier: PasswordVerifier, on conn: DatabaseConnectable) -> EventLoopFuture<User?> {
        User.DatabaseModel.authenticate(username: username, password: password, using: verifier, on: conn)
            .map { try $0?.content() }
    }

    public static var usernameKey: UsernameKey { fatalError() }
    public static var passwordKey: PasswordKey { fatalError() }

    public static func authenticate(using basic: BasicAuthorization, verifier: PasswordVerifier, on connection: DatabaseConnectable) -> EventLoopFuture<User?> {
        User.DatabaseModel.authenticate(using: basic, verifier: verifier, on: connection)
            .map { try $0?.content() }
    }
}

/// Allows users to be verified by bearer / token auth middleware.
extension User: TokenAuthenticatable {
    public typealias TokenType = User.Login.Token

    public static func authenticate(token: TokenType, on connection: DatabaseConnectable) -> EventLoopFuture<User?> {
        User.DatabaseModel.authenticate(token: .init(id: token.id, string: token.string, userID: token.userID), on: connection).map { try $0?.content() }
    }
}

extension User.DatabaseModel: SessionAuthenticatable { }
extension User: SessionAuthenticatable {
    public var sessionID: Int? { id }
    public static func authenticate(sessionID: User.ID, on connection: DatabaseConnectable) -> EventLoopFuture<User?> {
        User.DatabaseModel.authenticate(sessionID: sessionID, on: connection).map { try $0?.content() }
    }
}
extension User.Login.Token: BearerAuthenticatable, Token {
    public typealias UserType = User
    public typealias UserIDType = User.ID

    public static var tokenKey: TokenKey { fatalError() }
    public static var userIDKey: UserIDKey { fatalError() }

    public static func authenticate(using bearer: BearerAuthorization, on connection: DatabaseConnectable) -> EventLoopFuture<User.Login.Token?> {
        DatabaseModel.authenticate(using: bearer, on: connection).map { try $0?.content() }
    }

    public static func bearerAuthMiddleware() -> BearerAuthenticationMiddleware<User.Login.Token> { .init() }
}

extension User {
    public static func basicAuthMiddleware(using verifier: PasswordVerifier) -> BasicAuthenticationMiddleware<User> {
        BasicAuthenticationMiddleware(verifier: verifier)
    }

    public static func tokenAuthMiddleware() -> TokenAuthenticationMiddleware<User> {
        TokenAuthenticationMiddleware(bearer: User.Login.Token.bearerAuthMiddleware())
    }
}

/// Allows `User` to be used as a dynamic parameter in route definitions.
//extension User: ModelParameterRepresentable { }

extension User {
    struct UnknownUserMigration: PostgreSQLMigration {
        static func prepare(on conn: PostgreSQLConnection) -> EventLoopFuture<Void> {
            return User.DatabaseModel(
                id: nil,
                username: "Unknown",
                email: "unknown@kognita.no",
                passwordHash: "$2b$12$w8PoPj1yhROCdkAc2JjUJefWX91RztazdWo.D5kQhSdY.eSrT3wD6"
            )
                .create(on: conn)
                .transform(to: ())
        }

        static func revert(on conn: PostgreSQLConnection) -> EventLoopFuture<Void> {
            conn.future()
        }
    }
}

extension User {
    struct ViewedNotificationAtMigration: PostgreSQLMigration {

        static func revert(on conn: PostgreSQLConnection) -> EventLoopFuture<Void> {
            conn.future()
        }

        static func prepare(on conn: PostgreSQLConnection) -> EventLoopFuture<Void> {
            PostgreSQLDatabase.update(User.DatabaseModel.self, on: conn) { builder in
                builder.field(for: \User.DatabaseModel.viewedNotificationsAt)
            }
        }
    }
}
