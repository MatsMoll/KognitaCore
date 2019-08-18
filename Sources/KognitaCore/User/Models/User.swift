import Authentication
import FluentPostgreSQL
import Vapor

/// A registered user, capable of owning todo items.
public final class User: PostgreSQLModel {

    public static var createdAtKey: TimestampKey? = \.createdAt
    public static var updatedAtKey: TimestampKey? = \.updatedAt

    /// User's unique identifier.
    /// Can be `nil` if the user has not been saved yet.
    public var id: Int?

    /// User's full name.
    public private(set) var name: String

    /// User's email address.
    public private(set) var email: String

    /// BCrypt hash of the user's password.
    public private(set) var passwordHash: String

    /// A bool indicating if the user is a creator
    public private(set) var isCreator: Bool

    /// Can be `nil` if the user has not been saved yet.
    public var createdAt: Date?

    /// Can be `nil` if the user has not been saved yet.
    public var updatedAt: Date?

    /// A token used to activate other users
    public var activationToken: String?

    /// The user that recruteed the current user
    public var recruterUserID: User.ID?

    /// Creates a new `User`.
    init(id: Int? = nil, name: String, email: String, passwordHash: String, isCreator: Bool = false) {
        self.id = id
        self.name = name
        self.email = email.lowercased()
        self.passwordHash = passwordHash
        self.isCreator = isCreator
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
    func content(on conn: DatabaseConnectable) throws -> Future<UserResponse> {

        guard let registrationDate = createdAt else {
            throw Abort(.internalServerError)
        }
        var response = try UserResponse(id: requireID(), name: name, email: email, registrationDate: registrationDate, recruitierName: nil)
        guard let recruiterID =  recruterUserID else {
            return conn.future(response)
        }

        return User.find(recruiterID, on: conn)
            .map { recruiter in
                response.recruitierName = recruiter?.name
                return response
        }
    }
}


struct UserCreatedAtMigration: PostgreSQLMigration {

    static func prepare(on conn: PostgreSQLConnection) -> EventLoopFuture<Void> {
        return PostgreSQLDatabase.update(User.self, on: conn) { builder in
            builder.field(for: \.createdAt)
            builder.field(for: \.updatedAt)
            }
    }

    static func revert(on conn: PostgreSQLConnection) -> EventLoopFuture<Void> {
        return conn.future()
    }
}


struct UserRemoveCreatedAtMigration: PostgreSQLMigration {

    static func prepare(on conn: PostgreSQLConnection) -> EventLoopFuture<Void> {
        return PostgreSQLDatabase.update(User.self, on: conn) { builder in
            builder.deleteField(for: \.createdAt)
        }
    }

    static func revert(on conn: PostgreSQLConnection) -> EventLoopFuture<Void> {
        return conn.future()
    }
}


struct UserActivationTokenMigration: PostgreSQLMigration {

    static func prepare(on conn: PostgreSQLConnection) -> EventLoopFuture<Void> {
        return PostgreSQLDatabase.update(User.self, on: conn) { builder in
            builder.field(for: \.activationToken)
            builder.field(for: \.recruterUserID)
        }.flatMap { _ in
            User.query(on: conn)
                .filter(\.email == "mem@mollestad.no")
                .first()
                .flatMap { user in
                    if let user = user {
                        user.activationToken = UUID().uuidString
                        return user.save(on: conn)
                            .transform(to: ())
                    } else {
                        return conn.future()
                    }
            }
        }
    }

    static func revert(on conn: PostgreSQLConnection) -> EventLoopFuture<Void> {
        return PostgreSQLDatabase.update(User.self, on: conn) { builder in
            builder.deleteField(for: \.activationToken)
            builder.deleteField(for: \.recruterUserID)
        }
    }
}
