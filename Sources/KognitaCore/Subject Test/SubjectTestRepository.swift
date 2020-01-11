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
            case testHasNotBeenHeldYet
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
            guard test.openedAt == nil else {
                throw Abort(.badRequest)
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


        public static func taskWith(id: SubjectTest.Pivot.Task.ID, in session: TestSessionRepresentable, for user: User, on conn: DatabaseConnectable) throws -> EventLoopFuture<SubjectTest.MultipleChoiseTaskContent> {

            guard try session.userID == user.requireID() else {
                throw Abort(.forbidden)
            }

            return SubjectTest.Pivot.Task
                .query(on: conn)
                .join(\Task.id,                         to: \SubjectTest.Pivot.Task.taskID)
                .join(\MultipleChoiseTask.id,           to: \Task.id)
                .join(\MultipleChoiseTaskChoise.taskId, to: \MultipleChoiseTask.id)
                .filter(\SubjectTest.Pivot.Task.testID == session.testID)
                .filter(\SubjectTest.Pivot.Task.id == id)
                .decode(Task.self)
                .alsoDecode(MultipleChoiseTask.self)
                .alsoDecode(MultipleChoiseTaskChoise.self)
                .all()
                .flatMap { taskContent in

                    guard
                        let task = taskContent.first?.0.0,
                        let multipleChoiseTask = taskContent.first?.0.1
                    else {
                        throw Abort(.internalServerError)
                    }

                    return try TaskSessionAnswer.query(on: conn)
                        .join(\MultipleChoiseTaskAnswer.id, to: \TaskSessionAnswer.taskAnswerID)
                        .join(\MultipleChoiseTaskChoise.id, to: \MultipleChoiseTaskAnswer.choiseID)
                        .filter(\TaskSessionAnswer.sessionID == session.requireID())
                        .filter(\MultipleChoiseTaskChoise.taskId == task.requireID())
                        .decode(MultipleChoiseTaskAnswer.self)
                        .all()
                        .flatMap { answers in

                            SubjectTest.Pivot.Task.query(on: conn)
                                .filter(\.testID == session.testID)
                                .all()
                                .map { testTasks in

                                    SubjectTest.MultipleChoiseTaskContent(
                                        task: task,
                                        multipleChoiseTask: multipleChoiseTask,
                                        choises: taskContent.map { $0.1 },
                                        selectedChoises: answers,
                                        testTasks: testTasks
                                    )
                            }
                    }
            }
        }

        struct MultipleChoiseTaskAnswerCount: Codable {
            let numberOfAnswers: Int
        }

        public static func results(for test: SubjectTest, user: User, on conn: DatabaseConnectable) throws -> EventLoopFuture<Results> {
            guard user.isCreator else {
                throw Abort(.forbidden)
            }
            guard let heldAt = test.openedAt else {
                throw Errors.testHasNotBeenHeldYet
            }

            return conn.databaseConnection(to: .psql)
                .flatMap { conn in

                    try conn.select()
                        .all(table: Task.self)
                        .all(table: MultipleChoiseTaskChoise.self)
                        .column(.count(\MultipleChoiseTaskAnswer.id), as: "numberOfAnswers")
                        .from(SubjectTest.Pivot.Task.self)
                        .join(\SubjectTest.Pivot.Task.taskID,   to: \Task.id)
                        .join(\Task.id,                         to: \MultipleChoiseTaskChoise.taskId)
                        .join(\MultipleChoiseTaskChoise.id,     to: \MultipleChoiseTaskAnswer.choiseID, method: .left)
                        .join(\MultipleChoiseTaskAnswer.id,     to: \TaskSessionAnswer.taskAnswerID,    method: .left)
                        .join(\TaskSessionAnswer.sessionID,     to: \TestSession.id,                    method: .left)
                        .where(\SubjectTest.Pivot.Task.testID == test.requireID())
                        .groupBy(\Task.id)
                        .groupBy(\MultipleChoiseTaskChoise.id)
                        .all(decoding: Task.self, MultipleChoiseTaskChoise.self, MultipleChoiseTaskAnswerCount.self)
                        .map { tasks in
                            return Results(
                                title: test.title,
                                heldAt: heldAt,
                                taskResults: tasks.group(by: \.0.id)
                                    .compactMap { _, info in

                                        guard let task = info.first?.0 else {
                                            return nil
                                        }
                                        let totalCount = info.reduce(0) { $0 + $1.2.numberOfAnswers }

                                        return try? Results.MultipleChoiseTaskResult(
                                            taskID: task.requireID(),
                                            question: task.question,
                                            choises: info.map { _, choise, count in

                                                Results.MultipleChoiseTaskResult.Choise(
                                                    choise: choise.choise,
                                                    numberOfSubmissions: count.numberOfAnswers,
                                                    percentage: Double(count.numberOfAnswers) / Double(totalCount)
                                                )
                                            }
                                        )
                                }
                            )
                    }
            }
        }
    }
}

