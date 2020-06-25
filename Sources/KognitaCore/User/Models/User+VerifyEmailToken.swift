import Vapor
import FluentKit

public protocol VerifyEmailSendable {
//    func sendEmail(with token: User.VerifyEmail.EmailContent, on container: Container) throws -> EventLoopFuture<Void>
}

extension User {
    public enum VerifyEmail {
        public final class Token: Model {

            public static var entity: String = "User.VerifyEmail.Token"
            public static var schema: String = "User.VerifyEmail.Token"

            /// UserToken's unique identifier.
            @DBID(custom: "id")
            public var id: Int?

            /// Unique token string.
            @Field(key: "token")
            public var token: String

            /// Reference to user that owns this token.
            @Parent(key: "userID")
            var user: User.DatabaseModel

            init(token: String, userID: User.ID) {
                self.token = token
                self.$user.id = userID
            }

            public init() { }

            /// Creates a new `UserToken` for a given user.
            static func create(userID: User.ID) throws -> User.VerifyEmail.Token {
                let string = [UInt8].random(count: 16).base64
                // init a new `User.VerifyEmail.Token` from that string.
                return .init(token: string, userID: userID)
            }
        }

        public struct EmailContent {
            public let token: String
            public let userID: User.ID
            public let email: String
        }

        public struct Request: Content {
            public let token: String
        }
    }
}

extension User.VerifyEmail.Token {
    enum Migrations {}
}

extension User.VerifyEmail.Token.Migrations {
    struct Create: KognitaModelMigration {
        typealias Model = User.VerifyEmail.Token

        func build(schema: SchemaBuilder) -> SchemaBuilder {
            schema.field("token", .string, .required)
                .field("userID", .uint, .required, .references(User.DatabaseModel.schema, .id, onDelete: .cascade, onUpdate: .cascade))
        }
    }
}

extension User.VerifyEmail.Token {

    public func content(with email: String) -> User.VerifyEmail.EmailContent {
        .init(token: token, userID: $user.id, email: email)
    }
}

///// Allows `UserToken` to be used as a Fluent migration.
//extension User.VerifyEmail.Token: Migration {
//    /// See `Migration`.
//    public static func prepare(on conn: PostgreSQLConnection) -> Future<Void> {
//        return PostgreSQLDatabase.create(User.VerifyEmail.Token.self, on: conn) { builder in
//            try addProperties(to: builder)
//
//            builder.reference(from: \.userID, to: \User.DatabaseModel.id, onUpdate: .cascade, onDelete: .cascade)
//        }
//    }
//
//    public static func revert(on connection: PostgreSQLConnection) -> Future<Void> {
//        return PostgreSQLDatabase.delete(User.VerifyEmail.Token.self, on: connection)
//    }
//}
