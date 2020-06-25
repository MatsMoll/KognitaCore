import Foundation
import Vapor
import FluentKit

extension TestSession {
    final class DatabaseModel: KognitaPersistenceModel {

        public static var tableName: String = "TestSession"

        @DBID(custom: "id")
        public var id: Int?

        @Timestamp(key: "createdAt", on: .create)
        public var createdAt: Date?

        @Timestamp(key: "updatedAt", on: .update)
        public var updatedAt: Date?

        @Field(key: "submittedAt")
        public var submittedAt: Date?

        @Parent(key: "testID")
        public var test: SubjectTest.DatabaseModel

        public var hasSubmitted: Bool { submittedAt != nil }

        init() {}

        init(sessionID: TaskSession.IDValue, testID: SubjectTest.ID) {
            self.id = sessionID
            self.$test.id = testID
        }

        func representable(with session: TaskSession) -> TestSessionRepresentable {
            TestSession.TestParameter(session: session, testSession: self)
        }

        func representable(on database: Database) throws -> EventLoopFuture<TestSessionRepresentable> {
            let session = self
            return try TaskSession.find(requireID(), on: database)
                .unwrap(or: Abort(.internalServerError))
                .map { TestSession.TestParameter(session: $0, testSession: session) }
        }
    }
}

extension TestSession.DatabaseModel: ContentConvertable {
    func content() throws -> TestSession {
        try .init(
            id: requireID(),
            createdAt: createdAt ?? .now,
            submittedAt: submittedAt,
            testID: $test.id
        )
    }
}

extension TestSession {
    enum Migrations {
        struct Create: KognitaModelMigration {
            typealias Model = TestSession.DatabaseModel

            func build(schema: SchemaBuilder) -> SchemaBuilder {
                schema.field("submittedAt", .date)
                    .field("testID", .uint, .required, .references(SubjectTest.DatabaseModel.schema, .id, onDelete: .cascade, onUpdate: .cascade))
                    .foreignKey("id", references: TaskSession.schema, .id, onDelete: .cascade, onUpdate: .cascade)
                    .defaultTimestamps()
            }
        }
    }
}

extension TestSession: Content {}

extension TestSession {

    struct TestParameter: Codable, TestSessionRepresentable {

        let session: TaskSession
        let testSession: TestSession.DatabaseModel

        public var userID: User.ID { session.$user.id }
        public var createdAt: Date? { session.createdAt }
        public var testID: SubjectTest.ID { testSession.$test.id }
        public var submittedAt: Date? { testSession.submittedAt }
        public var executedAt: Date? { testSession.createdAt }

        public func requireID() throws -> Int { try session.requireID() }

        public func submit(on database: Database) throws -> EventLoopFuture<TestSessionRepresentable> {
            guard submittedAt == nil else {
                throw Abort(.badRequest)
            }
            testSession.submittedAt = .now
            return testSession.save(on: database)
                .transform(to: self)
        }

        public typealias ResolvedParameter = EventLoopFuture<TestParameter>
        public typealias ParameterModel = TestParameter

        public static func resolveWith(_ id: Int, database: Database) -> EventLoopFuture<TestParameter.ParameterModel> {
            return database.eventLoop.future(error: Abort(.notImplemented))
//            return TaskSession.query(on: conn)
//                .join(\TestSession.DatabaseModel.id, to: \TaskSession.id)
//                .filter(\TaskSession.id == id)
//                .alsoDecode(TestSession.DatabaseModel.self)
//                .first()
//                .unwrap(or: Abort(.internalServerError))
//                .map {
//                    return TestParameter(session: $0.0, testSession: $0.1)
//            }
        }
    }
}
