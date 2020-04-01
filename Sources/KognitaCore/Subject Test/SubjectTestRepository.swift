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
    static func currentlyOpenTest(for user: User, on conn: DatabaseConnectable) throws -> EventLoopFuture<SubjectTest.OverviewResponse?>

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

    static func scoreHistogram(for test: SubjectTest, user: User, on conn: DatabaseConnectable) throws -> EventLoopFuture<SubjectTest.ScoreHistogram>

    static func currentlyOpenTest(in subject: Subject, user: User, on conn: DatabaseConnectable) throws -> EventLoopFuture<SubjectTest.OverviewResponse?>
}


extension SubjectTest {

    public struct DatabaseRepository: SubjectTestRepositoring {

        public enum Errors: Error {
            case testIsClosed
            case alreadyEntered(sessionID: TaskSession.ID)
            case incorrectPassword
            case testHasNotBeenHeldYet
            case alreadyEnded
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
            let choiseID: MultipleChoiseTaskChoise.ID
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
                                .column(\MultipleChoiseTaskAnswer.choiseID)
                                .column(.count(\MultipleChoiseTaskAnswer.id), as: "numberOfAnswers")
                                .from(TestSession.self)
                                .join(\TestSession.id, to: \TaskSessionAnswer.sessionID)
                                .join(\TaskSessionAnswer.taskAnswerID, to: \MultipleChoiseTaskAnswer.id)
                                .groupBy(\MultipleChoiseTaskAnswer.choiseID)
                                .where(\TestSession.testID == test.requireID())
                                .all(decoding: MultipleChoiseTaskAnswerCount.self)
                                .flatMap { choiseCount in

                                    try conn.select()
                                        .all(table: Task.self)
                                        .all(table: MultipleChoiseTaskChoise.self)
                                        .from(SubjectTest.Pivot.Task.self)
                                        .join(\SubjectTest.Pivot.Task.taskID,   to: \Task.id)
                                        .join(\Task.id, to: \MultipleChoiseTaskChoise.taskId)
                                        .where(\SubjectTest.Pivot.Task.testID == test.requireID())
                                        .all(decoding: Task.self, MultipleChoiseTaskChoise.self)
                                        .flatMap { tasks in
                                            try calculateResultStatistics(
                                                for: test,
                                                tasks: tasks,
                                                choiseCount: choiseCount,
                                                user: user,
                                                on: conn
                                            )
                                    }
                            }
                    }
            }
        }

        private static func calculateResultStatistics(
            for test: SubjectTest,
            tasks: [(Task, MultipleChoiseTaskChoise)],
            choiseCount: [MultipleChoiseTaskAnswerCount],
            user: User,
            on conn: DatabaseConnectable
        ) throws -> EventLoopFuture<SubjectTest.Results> {

            guard let heldAt = test.openedAt else {
                throw Errors.testHasNotBeenHeldYet
            }

            var numberOfCorrectAnswers: Double = 0

            let grupedChoiseCount = choiseCount.reduce(into: [MultipleChoiseTaskChoise.ID : Int]()) { dict, choiseCount in
                dict[choiseCount.choiseID] = choiseCount.numberOfAnswers
            }

            let taskResults: [SubjectTest.Results.MultipleChoiseTaskResult] = tasks.group(by: \.0.id)
                .compactMap { _, info in

                    guard let task = info.first?.0 else {
                        return nil
                    }

                    var totalCount = info.reduce(0) { $0 + ((try? grupedChoiseCount[$1.1.requireID()]) ?? 0) }
                    let numberOfCorrectChoises = info.reduce(into: 0.0) { $0 += ($1.1.isCorrect ? 1 : 0) }
                    if totalCount == 0 { // In order to fix NaN values
                        totalCount = 1
                    }

                    return try? Results.MultipleChoiseTaskResult(
                        taskID: task.requireID(),
                        question: task.question,
                        description: task.description,
                        choises: info.map { _, choise in

                            let choiseCount = (try? grupedChoiseCount[choise.requireID()]) ?? 0
                            if choise.isCorrect {
                                numberOfCorrectAnswers += (Double(choiseCount) * 1 / numberOfCorrectChoises)
                            }

                            return Results.MultipleChoiseTaskResult.Choise(
                                choise: choise.choise,
                                numberOfSubmissions: choiseCount,
                                percentage: Double(choiseCount) / Double(totalCount),
                                isCorrect: choise.isCorrect
                            )
                        }
                    )
            }

            return try detailedUserResults(for: test, maxScore: Double(taskResults.count), user: user, on: conn)
                .flatMap { userResults in

                    try TestSession.query(on: conn)
                        .filter(\.testID == test.requireID())
                        .count()
                        .flatMap { numberOfSessions in

                            Subject.find(test.subjectID, on: conn)
                                .unwrap(or: Abort(.internalServerError))
                                .map { subject in

                                    Results(
                                        title: test.title,
                                        heldAt: heldAt,
                                        taskResults: taskResults,
                                        averageScore: (numberOfCorrectAnswers / Double(taskResults.count))/Double(numberOfSessions),
                                        subjectID: test.subjectID,
                                        subjectName: subject.name,
                                        userResults: userResults
                                    )
                            }
                    }
            }
        }

        public static func currentlyOpenTest(for user: User, on conn: DatabaseConnectable) throws -> EventLoopFuture<SubjectTest.OverviewResponse?> {

            return conn.databaseConnection(to: .psql)
                .flatMap { conn in

                    try conn.select()
                        .all(table: SubjectTest.self)
                        .all(table: Subject.self)
                        .from(SubjectTest.self)
                        .join(\SubjectTest.subjectID,   to: \User.ActiveSubject.subjectID)
                        .join(\SubjectTest.subjectID,   to: \Subject.id)
                        .where(\SubjectTest.openedAt != nil)
                        .where(\User.ActiveSubject.userID == user.requireID())
                        .all(decoding: SubjectTest.self, Subject.self)
                        .flatMap { tests in
                            guard let test = tests.first(where: { $0.0.isOpen }) else {
                                return conn.future(nil)
                            }
                            return try conn.select()
                                .all(table: TestSession.self)
                                .from(TestSession.self)
                                .join(\TestSession.id, to: \TaskSession.id)
                                .where(\TaskSession.userID == user.requireID())
                                .where(\TestSession.testID == test.0.requireID())
                                .limit(1)
                                .first(decoding: TestSession?.self)
                                .map { session in
                                    SubjectTest.OverviewResponse(
                                        test: test.0,
                                        subjectName: test.1.name,
                                        subjectID: test.1.id ?? 0,
                                        hasSubmitted: session?.hasSubmitted ?? false,
                                        testSessionID: session?.id
                                    )
                            }
                    }
            }
        }

        public static func currentlyOpenTest(in subject: Subject, user: User, on conn: DatabaseConnectable) throws -> EventLoopFuture<SubjectTest.OverviewResponse?> {

            return conn.databaseConnection(to: .psql)
                .flatMap { conn in

                    try conn.select()
                        .all(table: SubjectTest.self)
                        .all(table: Subject.self)
                        .from(SubjectTest.self)
                        .join(\SubjectTest.subjectID,   to: \User.ActiveSubject.subjectID)
                        .join(\SubjectTest.subjectID,   to: \Subject.id)
                        .where(\SubjectTest.openedAt != nil)
                        .where(\User.ActiveSubject.userID == user.requireID())
                        .where(\SubjectTest.subjectID == subject.requireID())
                        .all(decoding: SubjectTest.self, Subject.self)
                        .flatMap { tests in
                            guard let test = tests.first(where: { $0.0.isOpen }) else {
                                return conn.future(nil)
                            }
                            return try conn.select()
                                .all(table: TestSession.self)
                                .from(TestSession.self)
                                .join(\TestSession.id, to: \TaskSession.id)
                                .where(\TaskSession.userID == user.requireID())
                                .where(\TestSession.testID == test.0.requireID())
                                .limit(1)
                                .first(decoding: TestSession?.self)
                                .map { session in
                                    SubjectTest.OverviewResponse(
                                        test: test.0,
                                        subjectName: test.1.name,
                                        subjectID: test.1.id ?? 0,
                                        hasSubmitted: session?.hasSubmitted ?? false,
                                        testSessionID: session?.id
                                    )
                            }
                    }
            }
        }

        public static func all(in subject: Subject, for user: User, on conn: DatabaseConnectable) throws -> EventLoopFuture<[SubjectTest]> {

            try User.DatabaseRepository
                .isModerator(user: user, subjectID: subject.requireID(), on: conn)
                .flatMap {

                    try SubjectTest.query(on: conn)
                        .filter(\.subjectID == subject.requireID())
                        .sort(\.scheduledAt, .descending)
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
                throw Errors.alreadyEnded
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

        struct TestCountQueryResult: Codable {
            let taskCount: Int
        }

        struct HistogramQueryResult: Codable {
            let score: Double
            let sessionID: User.ID
        }

        public static func scoreHistogram(for test: SubjectTest, user: User, on conn: DatabaseConnectable) throws -> EventLoopFuture<SubjectTest.ScoreHistogram> {

            try User.DatabaseRepository
                .isModerator(user: user, subjectID: test.subjectID, on: conn)
                .flatMap { _ in

                    conn.databaseConnection(to: .psql)
                        .flatMap { conn in

                            try conn.select()
                                .column(.count(\SubjectTest.Pivot.Task.id), as: "taskCount")
                                .from(SubjectTest.Pivot.Task.self)
                                .where(\SubjectTest.Pivot.Task.testID == test.requireID())
                                .first(decoding: TestCountQueryResult.self)
                                .unwrap(or: Abort(.badRequest))
                                .flatMap { count in

                                    try conn.select()
                                        .column(\TaskResult.resultScore,    as: "score")
                                        .column(\TestSession.id,            as: "sessionID")
                                        .from(TestSession.self)
                                        .join(\TestSession.id, to: \TaskResult.sessionID)
                                        .where(\TestSession.testID == test.requireID())
                                        .all(decoding: HistogramQueryResult.self)
                                        .map { results in
                                            calculateHistogram(from: results, maxScore: count.taskCount)
                                    }
                            }
                    }
            }
        }

        static func calculateHistogram(from results: [HistogramQueryResult], maxScore: Int) -> SubjectTest.ScoreHistogram {

            let sessionResults = results.group(by: \.sessionID)
                .mapValues { results in
                    Int(results.reduce(into: 0.0) { $0 += $1.score }.rounded())
            }
            let numberOfSessions = sessionResults.count
            var histogram = (0...maxScore).reduce(into: [Int: Int]()) { $0[$1] = 0 }
            sessionResults.values.forEach { score in
                histogram[score] = (histogram[score] ?? 0) + 1
            }
            let scores = histogram.sorted(by: { $0.key < $1.key })
                .map { score, amount in
                    SubjectTest.ScoreHistogram.Score(
                        score: score,
                        amount: amount,
                        percentage: Double(amount) / Double(numberOfSessions)
                    )
            }
            return SubjectTest.ScoreHistogram(scores: scores)
        }

        private struct UserResultQueryResult: Codable {
            let userEmail: String
            let userID: User.ID
            let score: Double
        }

        public static func detailedUserResults(for test: SubjectTest, maxScore: Double, user: User, on conn: DatabaseConnectable) throws -> EventLoopFuture<[UserResult]> {

            guard maxScore != 0 else {
                throw Abort(.badRequest)
            }

            return try User.DatabaseRepository
                .isModerator(user: user, subjectID: test.subjectID, on: conn)
                .flatMap {

                    conn.databaseConnection(to: .psql)
                        .flatMap { conn in

                            try conn.select()
                                .column(\User.email,                as: "userEmail")
                                .column(\User.id,                   as: "userID")
                                .column(\TaskResult.resultScore,    as: "score")
                                .from(TaskResult.self)
                                .join(\TaskResult.sessionID, to: \TaskSession.id)
                                .join(\TaskSession.userID, to: \User.id)
                                .join(\TaskSession.id, to: \TestSession.id)
                                .where(\TestSession.testID == test.requireID())
                                .all(decoding: UserResultQueryResult.self)
                                .map { users in

                                    users.group(by: \.userID)
                                        .compactMap { (_, scores) in

                                            guard let userEmail = scores.first?.userEmail else {
                                                return nil
                                            }
                                            let score = scores.reduce(0.0) { $0 + $1.score }
                                            return UserResult(
                                                userEmail: userEmail,
                                                score: score,
                                                percentage: score / maxScore
                                            )
                                    }
                            }
                    }
            }
        }

        static func isOpen(testID: SubjectTest.ID, on conn: DatabaseConnectable) -> EventLoopFuture<Bool> {
            SubjectTest.find(testID, on: conn)
                .unwrap(or: Abort(.badRequest))
                .map { $0.isOpen }
        }

        public static func stats(for subject: Subject, on conn: DatabaseConnectable) throws -> EventLoopFuture<[SubjectTest.DetailedResult]> {
            return try SubjectTest.query(on: conn)
                .filter(\.subjectID == subject.requireID())
                .filter(\.endedAt != nil)
                .sort(\.openedAt, .ascending)
                .all()
                .flatMap { tests in

                    var lastTest: SubjectTest? = nil

                    return try tests.map { test in
                        defer { lastTest = test }
                        return try results(for: test, lastTest: lastTest, on: conn)
                    }
                    .flatten(on: conn)
            }
        }


        static func results(for test: SubjectTest, lastTest: SubjectTest? = nil, on conn: DatabaseConnectable) throws -> EventLoopFuture<SubjectTest.DetailedResult> {

            try SubjectTest.Pivot.Task.query(on: conn)
                .filter(\.testID == test.requireID())
                .count()
                .flatMap { numberOfTasks in

                    try TestSession.query(on: conn)
                        .join(\TaskResult.sessionID, to: \TestSession.id)
                        .filter(\.testID == test.requireID())
                        .decode(TaskResult.self)
                        .all()
                        .flatMap { testResults in

                            guard let endedAt = test.endedAt else { throw Abort(.badRequest) }

                            var query = PracticeSession.Pivot.Task.query(on: conn, withSoftDeleted: true)
                                .join(\TaskResult.sessionID,    to: \PracticeSession.Pivot.Task.sessionID)
                                .join(\Task.id,                 to: \TaskResult.taskID)
                                .join(\Subtopic.id,             to: \Task.subtopicID)
                                .join(\Topic.id,                to: \Subtopic.topicId)
                                .filter(\PracticeSession.Pivot.Task.isCompleted == true)
                                .filter(\Topic.subjectId == test.subjectID)
                                .filter(\PracticeSession.Pivot.Task.createdAt < endedAt)
                                .decode(TaskResult.self)

                            if let lastTest = lastTest, let lastEndedAt = lastTest.endedAt {
                                query = query.filter(\PracticeSession.Pivot.Task.createdAt > lastEndedAt)
                            }

                            return query.all()
                                .map { practiceResults in
                                    DetailedResult(
                                        testID: test.id ?? 0,
                                        testTitle: test.title,
                                        maxScore: Double(numberOfTasks),
                                        results: calculateStats(testResults: testResults, practiceResults: practiceResults)
                                    )
                            }
                    }
            }
        }

        static func calculateStats(testResults: [TaskResult], practiceResults: [TaskResult]) -> [SubjectTest.UserStats] {

            let groupedTestResults = testResults.group(by: \.userID.unsafelyUnwrapped)
            let groupedPracticeResults = practiceResults.group(by: \.userID.unsafelyUnwrapped)
                .mapValues { results in results.sorted(by: \TaskResult.timeUsed.unsafelyUnwrapped) }

            let testScores = groupedTestResults.mapValues { $0.reduce(0) { $0 + $1.resultScore } }
            let timePracticed = groupedPracticeResults.mapValues { $0.reduce(0) { $0 + ($1.timeUsed ?? 0) } }
            let medianTime: [User.ID : TimeInterval] = groupedPracticeResults.mapValues { results in
                if results.count % 2 == 1 {
                    return results[(results.count - 1)/2].timeUsed ?? 0
                } else {
                    return ((results[(results.count)/2].timeUsed ?? 0) + (results[(results.count)/2 + 1].timeUsed ?? 0)) / 2
                }
            }

            return testScores.map { userID, testScore in

                SubjectTest.UserStats(
                    timePracticed: timePracticed[userID] ?? 0,
                    medianTimePerTask: medianTime[userID] ?? 0,
                    numberOfTaskExecuted: (groupedPracticeResults[userID] ?? []).count,
                    testScore: testScore,
                    userID: userID
                )
            }
        }
    }
}



enum SortDirection {
    case acending
    case decending
}

extension Array {
    func sorted<T: Comparable>(by keyPath: KeyPath<Element, T>, direction: SortDirection = .acending) -> [Element] {
        let sortFunction: (Element, Element) -> Bool = direction == .acending ? { $0[keyPath: keyPath] > $1[keyPath: keyPath] } : { $0[keyPath: keyPath] < $1[keyPath: keyPath] }
        return sorted(by: sortFunction)
    }
}
