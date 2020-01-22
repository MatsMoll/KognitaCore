import FluentSQL
import Vapor

public protocol SubjectTestRepositoring:
    CreateModelRepository,
    UpdateModelRepository,
    DeleteModelRepository
    where
    CreateData      == SubjectTest.Create.Data,
    CreateResponse  == SubjectTest.Create.Response,
    UpdateData      == SubjectTest.Update.Data,
    UpdateResponse  == SubjectTest.Update.Response,
    Model           == SubjectTest
{
    /// Opens a test so users can enter
    /// - Parameters:
    ///   - test: The test to open
    ///   - user: The user that opens the test
    ///   - conn: The database connection
    /// - Returns: A future that contains the opend test
    static func open(test: SubjectTest, by user: User, on conn: DatabaseConnectable) throws -> EventLoopFuture<SubjectTest>


    /// A user enters a test in order to submit answers etc
    /// - Parameters:
    ///   - test: The test to enter
    ///   - request: The needed metadata to enter the test
    ///   - user: The user that enters the test
    ///   - conn: The database connection
    /// - Returns: A `TestSession` for the user
    static func enter(test: SubjectTest, with request: SubjectTest.Enter.Request, by user: User, on conn: DatabaseConnectable) throws -> EventLoopFuture<TestSession>

    /// Retrive data about the test
    /// - Parameters:
    ///   - test: The test to get the status for
    ///   - user: The user requesting the data
    ///   - conn: The database connection
    /// - Returns: A `SubjectTest.CompletionStatus` for a test
    static func userCompletionStatus(in test: SubjectTest, user: User, on conn: DatabaseConnectable) throws -> EventLoopFuture<SubjectTest.CompletionStatus>

    /// Fetches the task and it's metadata
    /// - Parameters:
    ///   - id: The id of the task to fetch
    ///   - session: The test session
    ///   - user: The user to fetch the data for
    ///   - conn: The database connection
    /// - Returns: The data needed to present a task
    static func taskWith(id: SubjectTest.Pivot.Task.ID, in session: TestSessionRepresentable, for user: User, on conn: DatabaseConnectable) throws -> EventLoopFuture<SubjectTest.MultipleChoiseTaskContent>

    /// Fetches the general results on a test
    /// - Parameters:
    ///   - test: The test to fetch the data for
    ///   - user: The user requesting the data
    ///   - conn: The database connection
    /// - Returns: The results of the test
    static func results(for test: SubjectTest, user: User, on conn: DatabaseConnectable) throws -> EventLoopFuture<SubjectTest.Results>

    /// Returns the tests that a user can enter in
    /// - Parameter user: The user to find the tests for
    /// - Parameter conn: The database connection
    static func currentlyOpenTest(for user: User, on conn: DatabaseConnectable) throws -> EventLoopFuture<SubjectTest?>

    /// Returns a list of all the different tests in a subject
    /// - Parameter subject: The subject the tests is for
    /// - Parameter user: The user that requests the tests
    /// - Parameter conn: The database connectino
    static func all(in subject: Subject, for user: User, on conn: DatabaseConnectable) throws -> EventLoopFuture<[SubjectTest]>

    /// Returns a test response for a given id
    /// - Parameters:
    ///   - id: The id of the test
    ///   - user: The user requestiong the test
    ///   - conn: The database connection
    static func taskIDsFor(testID id: SubjectTest.ID, on conn: DatabaseConnectable) throws -> EventLoopFuture<[Task.ID]>

    static func firstTaskID(testID: SubjectTest.ID, on conn: DatabaseConnectable) throws -> EventLoopFuture<SubjectTest.Pivot.Task.ID?>

    static func end(test: SubjectTest, by user: User, on conn: DatabaseConnectable) throws -> EventLoopFuture<Void>
}


extension SubjectTest {

    public struct DatabaseRepository: SubjectTestRepositoring {

        public enum Errors: Error {
            case testIsClosed
            case alreadyEntered(sessionID: TaskSession.ID)
            case incorrectPassword
            case testHasNotBeenHeldYet
        }

        public static func create(from content: SubjectTest.Create.Data, by user: User?, on conn: DatabaseConnectable) throws -> EventLoopFuture<SubjectTest> {
            guard let user = user else {
                throw Abort(.unauthorized)
            }

            return Subject.DatabaseRepository
                .subjectIDFor(taskIDs: content.tasks, on: conn)
                .flatMap { subjectID in

                    guard subjectID == content.subjectID else {
                        throw Abort(.badRequest)
                    }

                    return try User.DatabaseRepository
                        .isModerator(user: user, subjectID: subjectID, on: conn)
                        .flatMap {

                            SubjectTest(data: content)
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
            }
        }

        public static func update(model: SubjectTest, to data: SubjectTest.Update.Data, by user: User, on conn: DatabaseConnectable) throws -> EventLoopFuture<SubjectTest> {

            return Subject.DatabaseRepository
                .subjectIDFor(taskIDs: data.tasks, on: conn)
                .flatMap { subjectID in

                    guard subjectID == data.subjectID else {
                        throw Abort(.badRequest)
                    }

                    return try User.DatabaseRepository
                        .isModerator(user: user, subjectID: subjectID, on: conn)
                        .flatMap {

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
            }
        }

        public static func enter(test: SubjectTest, with request: SubjectTest.Enter.Request, by user: User, on conn: DatabaseConnectable) throws -> EventLoopFuture<TestSession> {
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

                    if let session = session {
                        throw try Errors.alreadyEntered(sessionID: session.requireID())
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

        public static func open(test: SubjectTest, by user: User, on conn: DatabaseConnectable) throws -> EventLoopFuture<SubjectTest> {
            guard test.openedAt == nil else {
                throw Abort(.badRequest)
            }
            return try User.DatabaseRepository
                .isModerator(user: user, subjectID: test.subjectID, on: conn)
                .flatMap {
                    test.open(on: conn)
            }
        }

        public static func userCompletionStatus(in test: SubjectTest, user: User, on conn: DatabaseConnectable) throws -> EventLoopFuture<CompletionStatus> {

            try User.DatabaseRepository
                .isModerator(user: user, subjectID: test.subjectID, on: conn)
                .flatMap {

                    try TestSession.query(on: conn)
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

                            SubjectTest.Pivot.Task
                                .query(on: conn)
                                .filter(\.testID == session.testID)
                                .all()
                                .flatMap { testTasks in

                                    SubjectTest
                                        .find(session.testID, on: conn)
                                        .unwrap(or: Abort(.internalServerError))
                                        .map { test in

                                            SubjectTest.MultipleChoiseTaskContent(
                                                test: test,
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
        }

        struct MultipleChoiseTaskAnswerCount: Codable {
            let numberOfAnswers: Int
        }

        public static func results(for test: SubjectTest, user: User, on conn: DatabaseConnectable) throws -> EventLoopFuture<Results> {
            guard test.endedAt != nil else {
                throw Errors.testHasNotBeenHeldYet
            }

            return try User.DatabaseRepository
                .isModerator(user: user, subjectID: test.subjectID, on: conn)
                .flatMap {

                    conn.databaseConnection(to: .psql)
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
                                .flatMap { tasks in
                                    return try calculateResultStatistics(for: test, tasks: tasks, on: conn)
                            }
                    }
            }
        }

        private static func calculateResultStatistics(for test: SubjectTest, tasks: [(Task, MultipleChoiseTaskChoise, MultipleChoiseTaskAnswerCount)], on conn: DatabaseConnectable) throws -> EventLoopFuture<SubjectTest.Results> {

            guard let heldAt = test.endedAt else {
                throw Errors.testHasNotBeenHeldYet
            }

            var numberOfCorrectAnswers: Double = 0

            let taskResults: [SubjectTest.Results.MultipleChoiseTaskResult] = tasks.group(by: \.0.id)
                .compactMap { _, info in

                    guard let task = info.first?.0 else {
                        return nil
                    }
                    var totalCount = info.reduce(0) { $0 + $1.2.numberOfAnswers }
                    if totalCount == 0 { // In order to fix NaN values
                        totalCount = 1
                    }

                    return try? Results.MultipleChoiseTaskResult(
                        taskID: task.requireID(),
                        question: task.question,
                        choises: info.map { _, choise, count in

                            if choise.isCorrect {
                                numberOfCorrectAnswers += Double(count.numberOfAnswers)
                            }

                            return Results.MultipleChoiseTaskResult.Choise(
                                choise: choise.choise,
                                numberOfSubmissions: count.numberOfAnswers,
                                percentage: Double(count.numberOfAnswers) / Double(totalCount),
                                isCorrect: choise.isCorrect
                            )
                        }
                    )
            }

            return try TestSession.query(on: conn)
                .filter(\.testID == test.requireID())
                .count()
                .map { numberOfSessions in

                    Results(
                        title: test.title,
                        heldAt: heldAt,
                        taskResults: taskResults,
                        averageScore: (numberOfCorrectAnswers / Double(taskResults.count))/Double(numberOfSessions)
                    )
            }
        }

        public static func currentlyOpenTest(for user: User, on conn: DatabaseConnectable) throws -> EventLoopFuture<SubjectTest?> {

            try SubjectTest.query(on: conn)
                .join(\User.ActiveSubject.subjectID, to: \SubjectTest.subjectID)
                .sort(\.openedAt, .descending)
                .filter(\.openedAt != nil)
                .filter(\User.ActiveSubject.userID == user.requireID())
                .all()
                .map { tests in
                    tests.first(where: { $0.isOpen })
            }
        }

        public static func all(in subject: Subject, for user: User, on conn: DatabaseConnectable) throws -> EventLoopFuture<[SubjectTest]> {

            try User.DatabaseRepository
                .isModerator(user: user, subjectID: subject.requireID(), on: conn)
                .flatMap {

                    try SubjectTest.query(on: conn)
                        .filter(\.subjectID == subject.requireID())
                        .sort(\.scheduledAt)
                        .all()
            }
        }

        public static func taskIDsFor(testID id: SubjectTest.ID, on conn: DatabaseConnectable) throws -> EventLoopFuture<[Task.ID]> {

            SubjectTest.Pivot.Task.query(on: conn)
                .filter(\.testID == id)
                .all()
                .map { rows in
                    return rows.map { $0.taskID }
            }
        }

        public static func firstTaskID(testID: SubjectTest.ID, on conn: DatabaseConnectable) throws -> EventLoopFuture<SubjectTest.Pivot.Task.ID?> {

            SubjectTest.Pivot.Task
                .query(on: conn)
                .filter(\.testID == testID)
                .sort(\.createdAt, .ascending)
                .first()
                .map { test in
                    test?.id
            }
        }

        public static func end(test: SubjectTest, by user: User, on conn: DatabaseConnectable) throws -> EventLoopFuture<Void> {

            guard
                let endedAt = test.endedAt,
                endedAt.timeIntervalSinceNow > 0
            else {
                throw Abort(.badRequest)
            }
            
            return try User.DatabaseRepository
                .isModerator(user: user, subjectID: test.subjectID, on: conn)
                .flatMap {
                    test.endedAt = .now
                    return test.save(on: conn)
                        .flatMap { _ in
                            try createResults(in: test, on: conn)
                    }
            }
        }

        static func createResults(in test: SubjectTest, on conn: DatabaseConnectable) throws -> EventLoopFuture<Void> {

            try TestSession.query(on: conn)
                .join(\TaskSession.id, to: \TestSession.id)
                .filter(\TestSession.testID == test.requireID())
                .filter(\TestSession.submittedAt == nil)
                .alsoDecode(TaskSession.self)
                .all()
                .flatMap { sessions in

                    try sessions.map { testSession, taskSession in
                        try TestSession.DatabaseRepository.createResult(
                            for: TaskSession.TestParameter(
                                session: taskSession,
                                testSession: testSession
                            ),
                            on: conn
                        )
                        .catchMap { _ in
                            // Ignoring errors in this case
                        }
                    }
                    .flatten(on: conn)
            }
        }
    }
}

