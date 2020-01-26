import Crypto
import Vapor
import FluentPostgreSQL


public protocol VerifyEmailSendable {
    func sendEmail(with token: User.VerifyEmail.EmailContent, on container: Container) -> EventLoopFuture<Void>
}


extension User {
    public enum VerifyEmail {
        final class Token: PostgreSQLModel {

            static var entity: String = "User.VerifyEmail.Token"
            static var name: String = "User.VerifyEmail.Token"

            /// UserToken's unique identifier.
            var id: Int?

            /// Unique token string.
            var token: String

            /// Reference to user that owns this token.
            var userID: User.ID

            init(token: String, userID: User.ID) {
                self.token = token
                self.userID = userID
            }

            /// Creates a new `UserToken` for a given user.
            static func create(userID: User.ID) throws -> User.VerifyEmail.Token {
                // generate a random 128-bit, base64-encoded string.
                let string = try CryptoRandom().generateData(count: 16).base64EncodedString()
                // init a new `User.VerifyEmail.Token` from that string.
                return .init(token: string, userID: userID)
            }
        }

        public struct EmailContent {
            let token: String
            let userID: User.ID
        }

        public struct Request: Content {
            public let token: String
        }
    }
}


extension User.VerifyEmail.Token {

    func content() -> User.VerifyEmail.EmailContent {
        .init(token: token, userID: userID)
    }

    func sendEmail(with container: Container) throws -> EventLoopFuture<Void> {
        let sender = try container.make(VerifyEmailSendable.self)
        return sender.sendEmail(with: self.content(), on: container)
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
