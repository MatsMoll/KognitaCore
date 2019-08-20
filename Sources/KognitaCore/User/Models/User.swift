import Authentication
import FluentPostgreSQL
import Vapor

/// A registered user, capable of owning todo items.
public final class User: PostgreSQLModel {

    public enum Role: String, PostgreSQLEnum, PostgreSQLMigration {
        case none
        case user
        case creator
        case admin
    }

    /// User's unique identifier.
    /// Can be `nil` if the user has not been saved yet.
    public var id: Int?

    /// User's full name.
    public private(set) var name: String

    /// User's email address.
    public private(set) var email: String

    /// BCrypt hash of the user's password.
    public private(set) var passwordHash: String

    /// The role of the User
    public private(set) var role: Role

    /// A bool indicating if the user is a creator
    public var isCreator: Bool { role == .creator || role == .admin }

    /// Can be `nil` if the user has not been saved yet.
    public var createdAt: Date?

    /// Can be `nil` if the user has not been saved yet.
    public var updatedAt: Date?

    /// A token used to activate other users
    public var loseAccessDate: Date?


    public static var createdAtKey: TimestampKey? = \.createdAt
    public static var updatedAtKey: TimestampKey? = \.updatedAt
    public static var deletedAtKey: TimestampKey? = \.loseAccessDate


    /// Creates a new `User`.
    init(id: Int? = nil, name: String, email: String, passwordHash: String, role: Role = .creator) {
        self.id = id
        self.name = name
        self.email = email.lowercased()
        self.passwordHash = passwordHash
        self.role = role
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
    public typealias TokenType = UserToken
}

extension User: SessionAuthenticatable { }

/// Allows `User` to be used as a Fluent migration.
extension User: Migration {
    /// See `Migration`.
    public static func prepare(on conn: PostgreSQLConnection) -> Future<Void> {
        return PostgreSQLDatabase.create(User.self, on: conn) { builder in
            try addProperties(to: builder)
            builder.unique(on: \.email)
        }
    }

    public static func revert(on connection: PostgreSQLConnection) -> Future<Void> {
        return PostgreSQLDatabase.delete(User.self, on: connection)
    }
}

/// Allows `User` to be used as a dynamic parameter in route definitions.
extension User: Parameter { }

extension User {
    func content() throws -> UserResponse {

        guard let registrationDate = createdAt else {
            throw Abort(.internalServerError)
        }
        return try UserResponse(id: requireID(), name: name, email: email, registrationDate: registrationDate)
    }
}
