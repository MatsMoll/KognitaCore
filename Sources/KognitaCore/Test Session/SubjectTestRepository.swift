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
            case alreadyEntered
            case incorrectPassword
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

        static func enter(test: SubjectTest, with request: SubjectTest.Enter.Request, by user: User, on conn: DatabaseConnectable) throws -> EventLoopFuture<TestSession> {
            guard test.isOpen else {
                throw Errors.testIsClosed
            }
            guard test.password == request.password else {
                throw Errors.incorrectPassword
            }
            return try TestSession.query(on: conn)
                .join(\TaskSession.id, to: \TestSession.id)
                .filter(\TaskSession.userID == user.requireID())
                .filter(\TestSession.testID == test.requireID())
                .first()
                .flatMap { session in

                    guard session == nil else {
                        throw Errors.alreadyEntered
                    }
                    return try TaskSession(userID: user.requireID())
                        .create(on: conn)
                        .flatMap { session in

                            try TestSession(
                                sessionID: session.requireID(),
                                testID: test.requireID()
                            )
                            .create(on: conn)
                    }
            }
        }

        static func open(test: SubjectTest, by user: User, on conn: DatabaseConnectable) throws -> EventLoopFuture<SubjectTest> {
            guard user.isCreator else {
                throw Abort(.forbidden)
            }
            return test.open(on: conn)
        }

        public static func userCompletionStatus(in test: SubjectTest, user: User, on conn: DatabaseConnectable) throws -> EventLoopFuture<CompletionStatus> {

            guard user.isCreator else {
                throw Abort(.forbidden)
            }

            return try TestSession.query(on: conn)
                .filter(\.testID == test.requireID())
                .all()
                .map { sessions in
                    sessions.reduce(
                        into: CompletionStatus(
                            amountOfCompletedUsers: 0,
                            amountOfEnteredUsers: 0
                        )
                    ) { status, session in
                        status.amountOfEnteredUsers += 1
                        if session.hasSubmitted {
                            status.amountOfCompletedUsers += 1
                        }
                    }

            }
        }
    }
}

