import FluentSQL
import Vapor

public protocol SubjectTestRepositoring: CreateModelRepository,
    UpdateModelRepository,
    DeleteModelRepository
    where
    CreateData      == SubjectTest.Create.Data,
    CreateResponse  == SubjectTest.Create.Response,
    UpdateData      == SubjectTest.Update.Data,
    UpdateResponse  == SubjectTest.Update.Response,
    Model           == SubjectTest {
    /// Opens a test so users can enter
    /// - Parameters:
    ///   - test: The test to open
    ///   - user: The user that opens the test
    ///   - conn: The database connection
    /// - Returns: A future that contains the opend test
    func open(test: SubjectTest, by user: User) throws -> EventLoopFuture<SubjectTest>

    /// A user enters a test in order to submit answers etc
    /// - Parameters:
    ///   - test: The test to enter
    ///   - request: The needed metadata to enter the test
    ///   - user: The user that enters the test
    ///   - conn: The database connection
    /// - Returns: A `TestSession` for the user
    func enter(test: SubjectTest, with request: SubjectTest.Enter.Request, by user: User) throws -> EventLoopFuture<TestSession>

    /// Retrive data about the test
    /// - Parameters:
    ///   - test: The test to get the status for
    ///   - user: The user requesting the data
    ///   - conn: The database connection
    /// - Returns: A `SubjectTest.CompletionStatus` for a test
    func userCompletionStatus(in test: SubjectTest, user: User) throws -> EventLoopFuture<SubjectTest.CompletionStatus>

    /// Fetches the task and it's metadata
    /// - Parameters:
    ///   - id: The id of the task to fetch
    ///   - session: The test session
    ///   - user: The user to fetch the data for
    ///   - conn: The database connection
    /// - Returns: The data needed to present a task
    func taskWith(id: Int, in session: TestSessionRepresentable, for user: User) throws -> EventLoopFuture<SubjectTest.MultipleChoiseTaskContent>

    /// Fetches the general results on a test
    /// - Parameters:
    ///   - test: The test to fetch the data for
    ///   - user: The user requesting the data
    ///   - conn: The database connection
    /// - Returns: The results of the test
    func results(for test: SubjectTest, user: User) throws -> EventLoopFuture<SubjectTest.Results>

    /// Returns the tests that a user can enter in
    /// - Parameter user: The user to find the tests for
    /// - Parameter conn: The database connection
    func currentlyOpenTest(for user: User) throws -> EventLoopFuture<SubjectTest.UserOverview?>

    /// Returns a list of all the different tests in a subject
    /// - Parameter subject: The subject the tests is for
    /// - Parameter user: The user that requests the tests
    /// - Parameter conn: The database connectino
    func all(in subject: Subject, for user: User) throws -> EventLoopFuture<[SubjectTest]>

    /// Returns a test response for a given id
    /// - Parameters:
    ///   - id: The id of the test
    ///   - user: The user requestiong the test
    ///   - conn: The database connection
    func taskIDsFor(testID id: SubjectTest.ID) throws -> EventLoopFuture<[Task.ID]>

    func firstTaskID(testID: SubjectTest.ID) throws -> EventLoopFuture<Int?>

    func end(test: SubjectTest, by user: User) throws -> EventLoopFuture<Void>

    func scoreHistogram(for test: SubjectTest, user: User) throws -> EventLoopFuture<SubjectTest.ScoreHistogram>

    func currentlyOpenTest(in subject: Subject, user: User) throws -> EventLoopFuture<SubjectTest.UserOverview?>

    func isOpen(testID: SubjectTest.ID) -> EventLoopFuture<Bool>

    func detailedUserResults(for test: SubjectTest, maxScore: Double, user: User) throws -> EventLoopFuture<[SubjectTest.UserResult]>
}

extension SubjectTest {

    //swiftlint:disable type_body_length
    public struct DatabaseRepository: SubjectTestRepositoring, DatabaseConnectableRepository {

        public let conn: DatabaseConnectable

        private var userRepository: some UserRepository { User.DatabaseRepository(conn: conn) }
        private var subjectRepository: some SubjectRepositoring { Subject.DatabaseRepository(conn: conn) }
        private var subjectTestTaskRepositoring: some SubjectTestTaskRepositoring { SubjectTest.Pivot.Task.DatabaseRepository(conn: conn) }
        private var testSessionRepository: some TestSessionRepositoring { TestSession.DatabaseRepository(conn: conn) }

        public enum Errors: Error {
            case testIsClosed
            case alreadyEntered(sessionID: TestSession.ID)
            case incorrectPassword
            case testHasNotBeenHeldYet
            case alreadyEnded
        }

        public func delete(model: SubjectTest, by user: User?) throws -> EventLoopFuture<Void> {
            deleteDatabase(SubjectTest.DatabaseModel.self, model: model)
        }

        public func create(from content: SubjectTest.Create.Data, by user: User?) throws -> EventLoopFuture<SubjectTest> {
            guard let user = user else {
                throw Abort(.unauthorized)
            }

            return subjectRepository
                .subjectIDFor(taskIDs: content.tasks)
                .flatMap { subjectID in

                    guard subjectID == content.subjectID else {
                        throw Abort(.badRequest)
                    }

                    return try self.userRepository
                        .isModerator(user: user, subjectID: subjectID)
                        .flatMap {

                            SubjectTest.DatabaseModel(data: content)
                                .create(on: self.conn)
                                .flatMap { test in
                                    try self.subjectTestTaskRepositoring
                                        .create(
                                            from: .init(
                                                testID: test.requireID(),
                                                taskIDs: content.tasks
                                            ),
                                            by: user
                                    )
                                    .map { _ in try test.content() }
                            }
                    }
            }
        }

        public func update(model: SubjectTest, to data: SubjectTest.Update.Data, by user: User) throws -> EventLoopFuture<SubjectTest> {

            return subjectRepository
                .subjectIDFor(taskIDs: data.tasks)
                .flatMap { subjectID in

                    guard subjectID == data.subjectID else {
                        throw Abort(.badRequest)
                    }

                    return try self.userRepository
                        .isModerator(user: user, subjectID: subjectID)
                        .flatMap {

                            self.updateDatabase(SubjectTest.DatabaseModel.self, model: model, to: data)
                                .flatMap { test in

                                    try self.subjectTestTaskRepositoring
                                        .update(
                                            model: test,
                                            to: data.tasks,
                                            by: user
                                    )
                                    .transform(to: test)
                            }
                    }
            }
        }

        public func enter(test: SubjectTest, with request: SubjectTest.Enter.Request, by user: User) throws -> EventLoopFuture<TestSession> {
            guard test.isOpen else {
                throw Errors.testIsClosed
            }
            guard test.password == request.password else {
                throw Errors.incorrectPassword
            }
            return TestSession.DatabaseModel.query(on: conn)
                .join(\TaskSession.id, to: \TestSession.DatabaseModel.id)
                .filter(\TaskSession.userID == user.id)
                .filter(\TestSession.testID == test.id)
                .first()
                .flatMap { session in

                    if let session = session {
                        throw try Errors.alreadyEntered(sessionID: session.requireID())
                    }
                    return TaskSession(userID: user.id)
                        .create(on: self.conn)
                        .flatMap { session in

                            try TestSession.DatabaseModel(
                                sessionID: session.requireID(),
                                testID: test.id
                            )
                            .create(on: self.conn)
                            .map { try $0.content() }
                    }
            }
        }

        public func open(test: SubjectTest, by user: User) throws -> EventLoopFuture<SubjectTest> {
            return try userRepository
                .isModerator(user: user, subjectID: test.subjectID)
                .flatMap {
                    SubjectTest.DatabaseModel.find(test.id, on: self.conn)
                        .unwrap(or: Abort(.badRequest))
                        .flatMap { test in
                            test.open(on: self.conn)
                                .map { try $0.content() }
                    }
            }
        }

        public func userCompletionStatus(in test: SubjectTest, user: User) throws -> EventLoopFuture<CompletionStatus> {

            try userRepository
                .isModerator(user: user, subjectID: test.subjectID)
                .flatMap {

                    TestSession.DatabaseModel.query(on: self.conn)
                        .filter(\.testID == test.id)
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

        public func taskWith(id: Int, in session: TestSessionRepresentable, for user: User) throws -> EventLoopFuture<SubjectTest.MultipleChoiseTaskContent> {

            guard session.userID == user.id else {
                throw Abort(.forbidden)
            }

            return SubjectTest.Pivot.Task
                .query(on: conn)
                .join(\Task.id, to: \SubjectTest.Pivot.Task.taskID)
                .join(\KognitaContent.MultipleChoiceTask.DatabaseModel.id, to: \Task.id)
                .join(\MultipleChoiseTaskChoise.taskId, to: \KognitaContent.MultipleChoiceTask.DatabaseModel.id)
                .filter(\SubjectTest.Pivot.Task.testID == session.testID)
                .filter(\SubjectTest.Pivot.Task.id == id)
                .decode(Task.self)
                .alsoDecode(KognitaContent.MultipleChoiceTask.DatabaseModel.self)
                .alsoDecode(MultipleChoiseTaskChoise.self)
                .all()
                .flatMap { taskContent in

                    guard
                        let task = taskContent.first?.0.0,
                        let multipleChoiseTask = taskContent.first?.0.1
                    else {
                        throw Abort(.internalServerError)
                    }

                    return try TaskSessionAnswer.query(on: self.conn)
                        .join(\MultipleChoiseTaskAnswer.id, to: \TaskSessionAnswer.taskAnswerID)
                        .join(\MultipleChoiseTaskChoise.id, to: \MultipleChoiseTaskAnswer.choiseID)
                        .filter(\TaskSessionAnswer.sessionID == session.requireID())
                        .filter(\MultipleChoiseTaskChoise.taskId == task.requireID())
                        .decode(MultipleChoiseTaskAnswer.self)
                        .all()
                        .flatMap { _ in

                            SubjectTest.Pivot.Task
                                .query(on: self.conn)
                                .filter(\.testID == session.testID)
                                .all()
                                .flatMap { _ in

                                    SubjectTest.DatabaseModel
                                        .find(session.testID, on: self.conn)
                                        .unwrap(or: Abort(.internalServerError))
                                        .map { _ in

                                            throw Abort(.notImplemented)
//                                            try SubjectTest.MultipleChoiseTaskContent(
//                                                test: test.content(),
//                                                task: task,
//                                                multipleChoiseTask: multipleChoiseTask,
//                                                choises: taskContent.map { $0.1 },
//                                                selectedChoises: answers,
//                                                testTasks: testTasks
//                                            )
                                    }
                            }
                    }
            }
        }

        struct MultipleChoiseTaskAnswerCount: Codable {
            let choiseID: MultipleChoiseTaskChoise.ID
            let numberOfAnswers: Int
        }

        public func results(for test: SubjectTest, user: User) throws -> EventLoopFuture<Results> {
            guard test.endedAt != nil else {
                throw Errors.testHasNotBeenHeldYet
            }

            return try userRepository
                .isModerator(user: user, subjectID: test.subjectID)
                .flatMap {

                    self.conn.databaseConnection(to: .psql)
                        .flatMap { conn in

                            conn.select()
                                .column(\MultipleChoiseTaskAnswer.choiseID)
                                .column(.count(\MultipleChoiseTaskAnswer.id), as: "numberOfAnswers")
                                .from(TestSession.DatabaseModel.self)
                                .join(\TestSession.DatabaseModel.id, to: \TaskSessionAnswer.sessionID)
                                .join(\TaskSessionAnswer.taskAnswerID, to: \MultipleChoiseTaskAnswer.id)
                                .groupBy(\MultipleChoiseTaskAnswer.choiseID)
                                .where(\TestSession.DatabaseModel.testID == test.id)
                                .all(decoding: MultipleChoiseTaskAnswerCount.self)
                                .flatMap { choiseCount in

                                    conn.select()
                                        .all(table: Task.self)
                                        .all(table: MultipleChoiseTaskChoise.self)
                                        .from(SubjectTest.Pivot.Task.self)
                                        .join(\SubjectTest.Pivot.Task.taskID, to: \Task.id)
                                        .join(\Task.id, to: \MultipleChoiseTaskChoise.taskId)
                                        .where(\SubjectTest.Pivot.Task.testID == test.id)
                                        .all(decoding: Task.self, MultipleChoiseTaskChoise.self)
                                        .flatMap { tasks in
                                            try self.calculateResultStatistics(
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

        private func calculateResultStatistics(
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

            let grupedChoiseCount = choiseCount.reduce(into: [MultipleChoiseTaskChoise.ID: Int]()) { dict, choiseCount in
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

            return try detailedUserResults(for: test, maxScore: Double(taskResults.count), user: user)
                .flatMap { userResults in

                    TestSession.DatabaseModel.query(on: self.conn)
                        .filter(\.testID == test.id)
                        .count()
                        .flatMap { numberOfSessions in

                            Subject.DatabaseModel.find(test.subjectID, on: self.conn)
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

        public func currentlyOpenTest(for user: User) throws -> EventLoopFuture<SubjectTest.UserOverview?> {

            return conn.databaseConnection(to: .psql)
                .flatMap { conn in

                    conn.select()
                        .all(table: SubjectTest.DatabaseModel.self)
                        .all(table: Subject.DatabaseModel.self)
                        .from(SubjectTest.DatabaseModel.self)
                        .join(\SubjectTest.DatabaseModel.subjectID, to: \User.ActiveSubject.subjectID)
                        .join(\SubjectTest.DatabaseModel.subjectID, to: \Subject.DatabaseModel.id)
                        .where(\SubjectTest.DatabaseModel.openedAt != nil)
                        .where(\User.ActiveSubject.userID == user.id)
                        .all(decoding: SubjectTest.DatabaseModel.self, Subject.self)
                        .flatMap { tests in
                            guard let test = tests.first(where: { $0.0.isOpen }) else {
                                return conn.future(nil)
                            }
                            return try conn.select()
                                .all(table: TestSession.DatabaseModel.self)
                                .from(TestSession.DatabaseModel.self)
                                .join(\TestSession.DatabaseModel.id, to: \TaskSession.id)
                                .where(\TaskSession.userID == user.id)
                                .where(\TestSession.DatabaseModel.testID == test.0.requireID())
                                .limit(1)
                                .first(decoding: TestSession?.self)
                                .map { session in
                                    try SubjectTest.UserOverview(
                                        test: test.0.content(),
                                        subjectName: test.1.name,
                                        subjectID: test.1.id,
                                        hasSubmitted: session?.hasSubmitted ?? false,
                                        testSessionID: session?.id
                                    )
                            }
                    }
            }
        }

        public func currentlyOpenTest(in subject: Subject, user: User) throws -> EventLoopFuture<SubjectTest.UserOverview?> {

            return conn.databaseConnection(to: .psql)
                .flatMap { conn in

                    conn.select()
                        .all(table: SubjectTest.DatabaseModel.self)
                        .all(table: Subject.DatabaseModel.self)
                        .from(SubjectTest.DatabaseModel.self)
                        .join(\SubjectTest.DatabaseModel.subjectID, to: \User.ActiveSubject.subjectID)
                        .join(\SubjectTest.DatabaseModel.subjectID, to: \Subject.DatabaseModel.id)
                        .where(\SubjectTest.DatabaseModel.openedAt != nil)
                        .where(\User.ActiveSubject.userID == user.id)
                        .where(\SubjectTest.DatabaseModel.subjectID == subject.id)
                        .all(decoding: SubjectTest.DatabaseModel.self, Subject.self)
                        .flatMap { tests in
                            guard let test = tests.first(where: { $0.0.isOpen }) else {
                                return conn.future(nil)
                            }
                            return try conn.select()
                                .all(table: TestSession.DatabaseModel.self)
                                .from(TestSession.DatabaseModel.self)
                                .join(\TestSession.DatabaseModel.id, to: \TaskSession.id)
                                .where(\TaskSession.userID == user.id)
                                .where(\TestSession.DatabaseModel.testID == test.0.requireID())
                                .limit(1)
                                .first(decoding: TestSession?.self)
                                .map(to: SubjectTest.UserOverview?.self) { session in

//                                    throw Abort(.notImplemented)
                                    try SubjectTest.UserOverview(
                                        test: test.0.content(),
                                        subjectName: test.1.name,
                                        subjectID: test.1.id,
                                        hasSubmitted: session?.hasSubmitted ?? false,
                                        testSessionID: session?.id
                                    )
                            }
                    }
            }
        }

        public func all(in subject: Subject, for user: User) throws -> EventLoopFuture<[SubjectTest]> {

            try userRepository
                .isModerator(user: user, subjectID: subject.id)
                .flatMap {

                    SubjectTest.DatabaseModel.query(on: self.conn)
                        .filter(\.subjectID == subject.id)
                        .sort(\.scheduledAt, .descending)
                        .all()
                        .map {
                            try $0.map { try $0.content() }
                    }
            }
        }

        public func taskIDsFor(testID id: SubjectTest.ID) throws -> EventLoopFuture<[Task.ID]> {

            SubjectTest.Pivot.Task.query(on: conn)
                .filter(\.testID == id)
                .all()
                .map { rows in
                    return rows.map { $0.taskID }
            }
        }

        public func firstTaskID(testID: SubjectTest.ID) throws -> EventLoopFuture<Int?> {

            SubjectTest.Pivot.Task
                .query(on: conn)
                .filter(\.testID == testID)
                .sort(\.createdAt, .ascending)
                .first()
                .map { test in
                    test?.id
            }
        }

        public func end(test: SubjectTest, by user: User) throws -> EventLoopFuture<Void> {

            guard
                let endedAt = test.endedAt,
                endedAt.timeIntervalSinceNow > 0
            else {
                throw Errors.alreadyEnded
            }

            return try userRepository
                .isModerator(user: user, subjectID: test.subjectID)
                .flatMap {
                    SubjectTest.DatabaseModel
                        .find(test.id, on: self.conn)
                        .unwrap(or: Abort(.badRequest))
                        .flatMap { test in
                            test.endedAt = .now
                            return test.save(on: self.conn)
                                .flatMap { _ in
                                    try self.createResults(in: test.content())
                            }
                    }
            }
        }

        func createResults(in test: SubjectTest) throws -> EventLoopFuture<Void> {

            TestSession.DatabaseModel.query(on: conn)
                .join(\TaskSession.id, to: \TestSession.DatabaseModel.id)
                .filter(\TestSession.DatabaseModel.testID == test.id)
                .filter(\TestSession.DatabaseModel.submittedAt == nil)
                .alsoDecode(TaskSession.self)
                .all()
                .flatMap { sessions in

                    try sessions.map { testSession, taskSession in
                        try self.testSessionRepository.createResult(
                            for: TaskSession.TestParameter(
                                session: taskSession,
                                testSession: testSession
                            )
                        )
                        .catchMap { _ in
                            // Ignoring errors in this case
                        }
                    }
                    .flatten(on: self.conn)
            }
        }

        struct TestCountQueryResult: Codable {
            let taskCount: Int
        }

        struct HistogramQueryResult: Codable {
            let score: Double
            let sessionID: User.ID
        }

        public func scoreHistogram(for test: SubjectTest, user: User) throws -> EventLoopFuture<SubjectTest.ScoreHistogram> {

            try userRepository
                .isModerator(user: user, subjectID: test.subjectID)
                .flatMap { _ in

                    self.conn.databaseConnection(to: .psql)
                        .flatMap { conn in

                            conn.select()
                                .column(.count(\SubjectTest.Pivot.Task.id), as: "taskCount")
                                .from(SubjectTest.Pivot.Task.self)
                                .where(\SubjectTest.Pivot.Task.testID == test.id)
                                .first(decoding: TestCountQueryResult.self)
                                .unwrap(or: Abort(.badRequest))
                                .flatMap { count in

                                    conn.select()
                                        .column(\TaskResult.DatabaseModel.resultScore, as: "score")
                                        .column(\TestSession.DatabaseModel.id, as: "sessionID")
                                        .from(TestSession.DatabaseModel.self)
                                        .join(\TestSession.DatabaseModel.id, to: \TaskResult.DatabaseModel.sessionID)
                                        .where(\TestSession.DatabaseModel.testID == test.id)
                                        .all(decoding: HistogramQueryResult.self)
                                        .map { results in
                                            self.calculateHistogram(from: results, maxScore: count.taskCount)
                                    }
                            }
                    }
            }
        }

        func calculateHistogram(from results: [HistogramQueryResult], maxScore: Int) -> SubjectTest.ScoreHistogram {

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

        public func detailedUserResults(for test: SubjectTest, maxScore: Double, user: User) throws -> EventLoopFuture<[UserResult]> {

            guard maxScore != 0 else {
                throw Abort(.badRequest)
            }

            return try userRepository
                .isModerator(user: user, subjectID: test.subjectID)
                .flatMap {

                    self.conn.databaseConnection(to: .psql)
                        .flatMap { conn in

                            conn.select()
                                .column(\User.DatabaseModel.email, as: "userEmail")
                                .column(\User.DatabaseModel.id, as: "userID")
                                .column(\TaskResult.DatabaseModel.resultScore, as: "score")
                                .from(TaskResult.DatabaseModel.self)
                                .join(\TaskResult.DatabaseModel.sessionID, to: \TaskSession.id)
                                .join(\TaskSession.userID, to: \User.DatabaseModel.id)
                                .join(\TaskSession.id, to: \TestSession.DatabaseModel.id)
                                .where(\TestSession.DatabaseModel.testID == test.id)
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

        public func isOpen(testID: SubjectTest.ID) -> EventLoopFuture<Bool> {
            SubjectTest.DatabaseModel.find(testID, on: conn)
                .unwrap(or: Abort(.badRequest))
                .map { $0.isOpen }
        }

        public func stats(for subject: Subject) throws -> EventLoopFuture<[SubjectTest.DetailedResult]> {
            return SubjectTest.DatabaseModel.query(on: conn)
                .filter(\.subjectID == subject.id)
                .filter(\.endedAt != nil)
                .sort(\.openedAt, .ascending)
                .all()
                .flatMap { tests in

                    var lastTest: SubjectTest.DatabaseModel?

                    return try tests.map { test in
                        defer { lastTest = test }
                        return try self.results(for: test.content(), lastTest: lastTest?.content())
                    }
                    .flatten(on: self.conn)
            }
        }

        func results(for test: SubjectTest, lastTest: SubjectTest? = nil) throws -> EventLoopFuture<SubjectTest.DetailedResult> {

            SubjectTest.Pivot.Task.query(on: conn)
                .filter(\.testID == test.id)
                .count()
                .flatMap { numberOfTasks in

                    TestSession.DatabaseModel.query(on: self.conn)
                        .join(\TaskResult.DatabaseModel.sessionID, to: \TestSession.DatabaseModel.id)
                        .filter(\.testID == test.id)
                        .decode(TaskResult.DatabaseModel.self)
                        .all()
                        .flatMap { testResults in

                            guard let endedAt = test.endedAt else { throw Abort(.badRequest) }

                            var query = PracticeSession.Pivot.Task.query(on: self.conn, withSoftDeleted: true)
                                .join(\TaskResult.DatabaseModel.sessionID, to: \PracticeSession.Pivot.Task.sessionID)
                                .join(\Task.id, to: \TaskResult.taskID)
                                .join(\Subtopic.DatabaseModel.id, to: \Task.subtopicID)
                                .join(\Topic.DatabaseModel.id, to: \Subtopic.DatabaseModel.topicId)
                                .filter(\PracticeSession.Pivot.Task.isCompleted == true)
                                .filter(\Topic.DatabaseModel.subjectId == test.subjectID)
                                .filter(\PracticeSession.Pivot.Task.createdAt < endedAt)
                                .decode(TaskResult.DatabaseModel.self)

                            if let lastTest = lastTest, let lastEndedAt = lastTest.endedAt {
                                query = query.filter(\PracticeSession.Pivot.Task.createdAt > lastEndedAt)
                            }

                            return query.all()
                                .map { practiceResults in
                                    DetailedResult(
                                        testID: test.id,
                                        testTitle: test.title,
                                        maxScore: Double(numberOfTasks),
                                        results: self.calculateStats(testResults: testResults, practiceResults: practiceResults)
                                    )
                            }
                    }
            }
        }

        func calculateStats(testResults: [TaskResult.DatabaseModel], practiceResults: [TaskResult.DatabaseModel]) -> [SubjectTest.UserStats] {

            let groupedTestResults = testResults.group(by: \.userID.unsafelyUnwrapped)
            let groupedPracticeResults = practiceResults.group(by: \.userID.unsafelyUnwrapped)
                .mapValues { results in results.sorted(by: \TaskResult.DatabaseModel.timeUsed.unsafelyUnwrapped) }

            let testScores = groupedTestResults.mapValues { $0.reduce(0) { $0 + $1.resultScore } }
            let timePracticed = groupedPracticeResults.mapValues { $0.reduce(0) { $0 + ($1.timeUsed ?? 0) } }
            let medianTime: [User.ID: TimeInterval] = groupedPracticeResults.mapValues { results in
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

//extension SubjectTest.MultipleChoiseTaskContent {
//    init(test: SubjectTest, task: Task, multipleChoiseTask: KognitaCore.MultipleChoiseTask, choises: [MultipleChoiseTaskChoise], selectedChoises: [MultipleChoiseTaskAnswer], testTasks: [SubjectTest.Pivot.Task]) {
//        self.init(
//            test: test,
//            task: MultipleChoiceTask(task: task, multipleChoiceTask: multipleChoiseTask),
//            choises: choises.compactMap { choise in
//                try? Choise(
//                    id: choise.requireID(),
//                    choise: choise.choise,
//                    isCorrect: choise.isCorrect,
//                    isSelected: selectedChoises.contains(where: { $0.choiseID == choise.id })
//                )
//            },
//            testTasks: testTasks.compactMap { testTask in
//                guard let testTaskID = testTask.id else {
//                    return nil
//                }
//                return SubjectTest.AssignedTask(
//                    testTaskID: testTaskID,
//                    isCurrent: testTask.taskID == task.id
//                )
//            }
//        )
//    }
//}

//extension SubjectTest.MultipleChoiceTask {
//    public init(task: Task, multipleChoiceTask: KognitaCore.MultipleChoiseTask) {
//        self.init(
//            test: test,
//            id: <#T##Int#>,
//            subtopicID: <#T##Subtopic.ID#>,
//            description: <#T##String?#>,
//            question: <#T##String#>,
//            creatorID: <#T##User.ID?#>,
//            examType: <#T##ExamTaskType?#>,
//            examYear: <#T##Int?#>,
//            isTestable: <#T##Bool#>,
//            createdAt: <#T##Date?#>,
//            updatedAt: <#T##Date?#>,
//            editedTaskID: <#T##Int?#>,
//            isMultipleSelect: <#T##Bool#>,
//            choises: <#T##[Choise]#>,
//            tasks: <#T##[SubjectTest.AssignedTask]#>
//        )
//        self.init(
//            id: task.id ?? 0,
//            subtopicID: task.subtopicID,
//            question: task.question,
//            isTestable: task.isTestable,
//            isMultipleSelect: multipleChoiceTask.isMultipleSelect,
//            choises: []
//        )
//    }
//}
