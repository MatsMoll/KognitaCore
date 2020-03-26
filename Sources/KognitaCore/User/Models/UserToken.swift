import Authentication
import Crypto
import FluentPostgreSQL
import Vapor

/// An ephermal authentication token that identifies a registered user.
extension User {
    public enum Login {}
}
extension User.Login {
    public final class Token: PostgreSQLModel {

        public typealias Database = PostgreSQLDatabase

        public static var entity: String = "User.Login.Token"
        public static var name: String = "User.Login.Token"

        /// Creates a new `UserToken` for a given user.
        static func create(userID: User.ID) throws -> User.Login.Token {
            // generate a random 128-bit, base64-encoded string.
            let string = try CryptoRandom().generateData(count: 16).base64EncodedString()
            // init a new `UserToken` from that string.
            return .init(string: string, userID: userID)
        }

        /// See `Model`.
        public static var deletedAtKey: TimestampKey? { return \.expiresAt }

        /// UserToken's unique identifier.
        public var id: Int?

        /// Unique token string.
        public var string: String

        /// Reference to user that owns this token.
        public var userID: User.ID

        /// Expiration date. Token will no longer be valid after this point.
        public var expiresAt: Date?

        /// Creates a new `UserToken`.
        init(id: Int? = nil, string: String, userID: User.ID) {
            self.id = id
            self.string = string
            // set token to expire after 5 hours
            self.expiresAt = Date.init(timeInterval: 60 * 60 * 5, since: .init())
            self.userID = userID
        }
    }
}

extension User.Login.Token {
    /// Fluent relation to the user that owns this token.
    var user: Parent<User.Login.Token, User> {
        return parent(\.userID)
    }
}

/// Allows this model to be used as a TokenAuthenticatable's token.
extension User.Login.Token: Token {
    /// See `Token`.
    public typealias UserType = User

    /// See `Token`.
    public static var tokenKey: WritableKeyPath<User.Login.Token, String> {
        return \.string
    }

    /// See `Token`.
    public static var userIDKey: WritableKeyPath<User.Login.Token, User.ID> {
        return \.userID
    }
}

/// Allows `UserToken` to be used as a Fluent migration.
extension User.Login.Token: Migration {
    /// See `Migration`.
    public static func prepare(on conn: PostgreSQLConnection) -> Future<Void> {
        return PostgreSQLDatabase.create(User.Login.Token.self, on: conn) { builder in
            try addProperties(to: builder)

            builder.reference(from: \.userID, to: \User.id, onUpdate: .cascade, onDelete: .setDefault)
        }.flatMap {
            PostgreSQLDatabase.update(User.Login.Token.self, on: conn) { builder in
                builder.deleteField(for: \.userID)
                builder.field(for: \.userID, type: .int, .default(1))
            }
        }
    }

    public static func revert(on connection: PostgreSQLConnection) -> Future<Void> {
        return PostgreSQLDatabase.delete(User.Login.Token.self, on: connection)
    }
}

/// Allows `UserToken` to be encoded to and decoded from HTTP messages.
extension User.Login.Token: Content { }

/// Allows `UserToken` to be used as a dynamic parameter in route definitions.
extension User.Login.Token: ModelParameterRepresentable { }
