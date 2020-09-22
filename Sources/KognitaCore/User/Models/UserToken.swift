import Crypto
import Vapor
import FluentKit

/// An ephermal authentication token that identifies a registered user.

extension User.Login.Token {
    final class DatabaseModel: Model {

        public static var schema: String = "User.Login.Token"

        /// Creates a new `UserToken` for a given user.
        static func create(userID: User.ID) throws -> User.Login.Token.DatabaseModel {
            // generate a random 128-bit, base64-encoded string.
            let string = [UInt8].random(count: 32).base64
            // init a new `UserToken` from that string.
            return .init(string: string, userID: userID)
        }

        /// See `Model`

        /// UserToken's unique identifier.
        @DBID(custom: "id")
        public var id: Int?

        /// Unique token string.
        @Field(key: "string")
        public var string: String

        /// Reference to user that owns this token.
        @Parent(key: "userID")
        public var user: User.DatabaseModel

        /// Expiration date. Token will no longer be valid after this point.
        @Field(key: "expiresAt")
        public var expiresAt: Date

        /// Creates a new `UserToken`.
        init(id: Int? = nil, string: String, userID: User.ID) {
            self.id = id
            self.string = string
            // set token to expire after 5 hours
            self.expiresAt = Date.init(timeInterval: 60 * 60 * 5, since: .init())
            self.$user.id = userID
        }

        init() {}
    }
}

/// Allows this model to be used as a TokenAuthenticatable's token.
extension User.Login.Token.DatabaseModel {
    /// See `Token`.
    var isValid: Bool { expiresAt.timeIntervalSinceNow > 0 }
    static var valueKey: KeyPath<User.Login.Token.DatabaseModel, Field<String>> = \.$string
    static var userKey: KeyPath<User.Login.Token.DatabaseModel, Parent<User.DatabaseModel>> = \.$user
}

extension User.Login.Token {
    enum Migrations {}
}

extension User.Login.Token.Migrations {
    struct Create: Migration {

        let schema = User.Login.Token.DatabaseModel.schema

        func prepare(on database: Database) -> EventLoopFuture<Void> {
            database.schema(schema)
                .field("id", .uint, .identifier(auto: true))
                .field("userID", .uint, .references(User.DatabaseModel.schema, .id, onDelete: .setDefault, onUpdate: .cascade), .sql(.default(1)))
                .field("expiresAt", .datetime, .required)
                .field("string", .string, .required)
                .create()
        }

        func revert(on database: Database) -> EventLoopFuture<Void> {
            database.schema(schema).delete()
        }
    }
}

/// Allows `UserToken` to be encoded to and decoded from HTTP messages.
extension User.Login.Token: Content { }
extension User.Login.Token.DatabaseModel: ContentConvertable {
    func content() throws -> User.Login.Token {
        try .init(
            id: requireID(),
            string: string,
            userID: $user.id,
            expiresAt: expiresAt
        )
    }
}

/// Allows `UserToken` to be used as a dynamic parameter in route definitions.
//extension User.Login.Token: ModelParameterRepresentable { }
