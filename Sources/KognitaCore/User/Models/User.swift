import Authentication
import FluentPostgreSQL
import Vapor

public protocol UserContent {
    var userId: Int { get }
    var username: String { get }
    var email: String { get }
}

/// A registered user, capable of owning todo items.
public final class User: KognitaCRUDModel {

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

    public static func addTableConstraints(to builder: SchemaCreator<User>) {
        builder.unique(on: \.email)
        builder.unique(on: \.username)
    }

    public func update(password: String) throws {
        passwordHash = try BCrypt.hash(password)
    }
}

/// Allows users to be verified by basic / password auth middleware.
extension User: PasswordAuthenticatable {
    /// See `PasswordAuthenticatable`.
    public static var usernameKey: WritableKeyPath<User, String> = \.email

    /// See `PasswordAuthenticatable`.
    public static var passwordKey: WritableKeyPath<User, String> = \.passwordHash
}

/// Allows users to be verified by bearer / token auth middleware.
extension User: TokenAuthenticatable {

    /// See `TokenAuthenticatable`.
    public typealias TokenType = User.Login.Token
}

extension User: SessionAuthenticatable { }

/// Allows `User` to be used as a dynamic parameter in route definitions.
extension User: ModelParameterRepresentable { }

extension User {

    public func content() throws -> User.Response {
        try User.Response(
            userId: requireID(),
            username: username,
            email: email,
            registrationDate: createdAt ?? Date()
        )
    }
}

extension User {
    struct UnknownUserMigration: PostgreSQLMigration {
        static func prepare(on conn: PostgreSQLConnection) -> EventLoopFuture<Void> {
            return User(
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
            PostgreSQLDatabase.update(User.self, on: conn) { builder in
                builder.field(for: \User.viewedNotificationsAt)
            }
        }
    }
}
