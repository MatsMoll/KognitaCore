import FluentSQL
import Vapor

public protocol SubjectTestRepositoring:
    CreateModelRepository,
    UpdateModelRepository
    where
    CreateData      == SubjectTest.Create.Data,
    CreateResponse  == SubjectTest.Create.Response,
    UpdateData      == SubjectTest.Create.Data,
    UpdateResponse  == SubjectTest.Create.Response,
    Model           == SubjectTest
{}


extension SubjectTest {

    struct DatabaseRepository: SubjectTestRepositoring {

        public enum Errors: Error {
            case testIsClosed
        }

        static func create(from content: SubjectTest.Create.Data, by user: User?, on conn: DatabaseConnectable) throws -> EventLoopFuture<SubjectTest> {
            guard let user = user else {
                throw Abort(.unauthorized)
            }
            guard user.isCreator else {
                throw Abort(.forbidden)
            }
            return SubjectTest(data: content)
                .create(on: conn)
                .flatMap { test in
                    try SubjectTest.Pivot.Task
                        .DatabaseRepository
                        .create(
                            from: .init(
                                testID: test.requireID(),
                                taskIDs: content.tasks
                            ),
                            by: user,
                            on: conn
                    )
                    .transform(to: test)
            }
        }

        static func update(model: SubjectTest, to data: SubjectTest.Update.Data, by user: User, on conn: DatabaseConnectable) throws -> EventLoopFuture<SubjectTest> {
            guard user.isCreator else {
                throw Abort(.forbidden)
            }
            return model.update(with: data)
                .save(on: conn)
                .flatMap { test in
                    try SubjectTest.Pivot.Task
                        .DatabaseRepository
                        .update(
                            model: test,
                            to: data.tasks,
                            by: user,
                            on: conn
                    )
                    .transform(to: test)
            }
        }

        static func enter(test: SubjectTest, by user: User, on conn: DatabaseConnectable) throws -> EventLoopFuture<TestSession> {
            guard test.isOpen else {
                throw Errors.testIsClosed
            }
            return try TestSession(
                testID: test.requireID(),
                userID: user.requireID()
            )
            .save(on: conn)
        }
    }
}

