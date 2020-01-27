import Vapor
import FluentPostgreSQL


public protocol VerifyEmailSendable {
    func sendEmail(with token: User.VerifyEmail.EmailContent, on container: Container) throws -> EventLoopFuture<Void>
}


extension User {
    public enum VerifyEmail {
        public final class Token: PostgreSQLModel {

            public static var entity: String = "User.VerifyEmail.Token"
            public static var name: String = "User.VerifyEmail.Token"

            /// UserToken's unique identifier.
            public var id: Int?

            /// Unique token string.
            public var token: String

            /// Reference to user that owns this token.
            public var userID: User.ID

            init(token: String, userID: User.ID) {
                self.token = token
                self.userID = userID
            }

            /// Creates a new `UserToken` for a given user.
            static func create(userID: User.ID) throws -> User.VerifyEmail.Token {
                let string = UUID().uuidString
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

    public func content(with email: String) -> User.VerifyEmail.EmailContent {
        .init(token: token, userID: userID, email: email)
    }
}


/// Allows `UserToken` to be used as a Fluent migration.
extension User.VerifyEmail.Token: Migration {
    /// See `Migration`.
    public static func prepare(on conn: PostgreSQLConnection) -> Future<Void> {
        return PostgreSQLDatabase.create(User.VerifyEmail.Token.self, on: conn) { builder in
            try addProperties(to: builder)

            builder.reference(from: \.userID, to: \User.id, onUpdate: .cascade, onDelete: .cascade)
        }
    }

    public static func revert(on connection: PostgreSQLConnection) -> Future<Void> {
        return PostgreSQLDatabase.delete(User.VerifyEmail.Token.self, on: connection)
    }
}
