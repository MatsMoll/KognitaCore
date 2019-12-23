import Authentication
import FluentPostgreSQL
import Vapor


public protocol UserContent {
    var userId: Int { get }
    var username: String { get }
    var email: String { get }
    var isCreator: Bool { get }
}

/// A registered user, capable of owning todo items.
public final class User: KognitaCRUDModel, UserContent {

    public enum Role: String, PostgreSQLEnum, PostgreSQLMigration {
        case none
        case user
        case creator
        case admin
    }

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
    public private(set) var role: Role

    /// Can be `nil` if the user has not been saved yet.
    public var createdAt: Date?

    /// Can be `nil` if the user has not been saved yet.
    public var updatedAt: Date?

    /// A token used to activate other users
//    public var loseAccessDate: Date?

//    public static var deletedAtKey: TimestampKey? = \.loseAccessDate

    /// Creates a new `User`.
    init(id: Int? = nil, username: String, email: String, passwordHash: String, role: Role) {
        self.id = id
        self.username = username
        self.email = email.lowercased()
        self.passwordHash = passwordHash
        self.role = role
    }
    
    public static func addTableConstraints(to builder: SchemaCreator<User>) {
        builder.unique(on: \.email)
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
    public typealias TokenType = UserToken
}

extension User: SessionAuthenticatable { }

/// Allows `User` to be used as a dynamic parameter in route definitions.
extension User: Parameter { }


extension User {
    /// A bool indicating if the user is a creator
    public var isCreator: Bool { return role == .creator || role == .admin }
    
    public func content() throws -> User.Response {
        return try User.Response(
            userId:             requireID(),
            username:           username,
            email:              email,
            registrationDate:   createdAt ?? Date(),
            isCreator:          isCreator
        )
    }
}

extension User : KognitaModelUpdatable {
    
    public func updateValues(with content: User.Edit.Data) throws {
//        self.name = content.name
    }
}
