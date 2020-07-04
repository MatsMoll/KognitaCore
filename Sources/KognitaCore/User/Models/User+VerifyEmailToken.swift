import Vapor
import FluentKit

public protocol VerifyEmailSendable {
    func sendEmail(with token: User.VerifyEmail.EmailContent) throws -> EventLoopFuture<Void>
}

extension User.VerifyEmail.Token {
    public final class DatabaseModel: Model {

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
        static func create(userID: User.ID) throws -> User.VerifyEmail.Token.DatabaseModel {
            let string = [UInt8].random(count: 16).base64
            // init a new `User.VerifyEmail.Token` from that string.
            return .init(token: string, userID: userID)
        }
    }
}

extension User.VerifyEmail.Token {
    enum Migrations {}
}

extension User.VerifyEmail.Token.Migrations {
    struct Create: KognitaModelMigration {
        typealias Model = User.VerifyEmail.Token.DatabaseModel

        func build(schema: SchemaBuilder) -> SchemaBuilder {
            schema.field("token", .string, .required)
                .field("userID", .uint, .required, .references(User.DatabaseModel.schema, .id, onDelete: .cascade, onUpdate: .cascade))
        }
    }
}

extension User.VerifyEmail.Token.DatabaseModel {

    public func content(with email: String) -> User.VerifyEmail.EmailContent {
        .init(token: token, userID: $user.id, email: email)
    }
}
