import FluentSQL
import Vapor

enum PostgreSQLDatePart: String {
    case year
    case day
    case week
}

extension SQLSelectBuilder {
    func column<T: Model, Value>(_ path: KeyPath<T, FieldProperty<T, Value>>) -> Self {
        self.column(table: T.schemaOrAlias, column: T()[keyPath: path].key.description)
    }

    func column<T: Model, Value>(_ path: KeyPath<T, IDProperty<T, Value>>) -> Self {
        self.column(table: T.schemaOrAlias, column: T()[keyPath: path].key.description)
    }

    func column<T: Model, Value>(_ path: KeyPath<T, FieldProperty<T, Value>>, as identifier: String) -> Self {
        return self.column(SQLAlias(SQLColumn(T()[keyPath: path].key.description, table: T.schemaOrAlias), as: SQLIdentifier(identifier)))
    }

    func column<T: Model, Format: TimestampFormat>(_ path: KeyPath<T, TimestampProperty<T, Format>>, as identifier: String) -> Self {
        return self.column(SQLAlias(SQLColumn(T()[keyPath: path].$timestamp.key.description, table: T.schemaOrAlias), as: SQLIdentifier(identifier)))
    }

    func column<T: Model, Value>(_ path: KeyPath<T, IDProperty<T, Value>>, as identifier: String) -> Self {
        return self.column(SQLAlias(SQLColumn(T()[keyPath: path].key.description, table: T.schemaOrAlias), as: SQLIdentifier(identifier)))
    }

    func count<T: Model, Value>(_ path: KeyPath<T, IDProperty<T, Value>>, as identifier: String) -> Self {
        return self.column(SQLAlias(SQLFunction("COUNT", args: SQLColumn(T()[keyPath: path].key.description, table: T.schemaOrAlias)), as: SQLIdentifier(identifier)))
    }

    func sum<T: Model, Value>(_ path: KeyPath<T, IDProperty<T, Value>>, as identifier: String) -> Self {
        return self.column(SQLAlias(SQLFunction("SUM", args: SQLColumn(T()[keyPath: path].key.description, table: T.schemaOrAlias)), as: SQLIdentifier(identifier)))
    }

    func sum<T: Model, Value>(_ path: KeyPath<T, FieldProperty<T, Value>>, as identifier: String) -> Self {
        return self.column(SQLAlias(SQLFunction("SUM", args: SQLColumn(T()[keyPath: path].key.description, table: T.schemaOrAlias)), as: SQLIdentifier(identifier)))
    }

    func date<T: Model, Format: TimestampFormat>(part: PostgreSQLDatePart, from path: KeyPath<T, TimestampProperty<T, Format>>, as identifier: String) -> Self {
        return self.column(SQLAlias(SQLFunction("date_part", args: [SQLQueryString("'\(part.rawValue)'"), SQLColumn(T()[keyPath: path].$timestamp.key.description, table: T.schemaOrAlias)]), as: SQLIdentifier(identifier)))
    }

    func groupBy<T: Model, Value>(_ path: KeyPath<T, FieldProperty<T, Value>>) -> Self {
        self.groupBy(SQLColumn(T()[keyPath: path].key.description, table: T.schemaOrAlias))
    }

    func groupBy<T: Model, Value>(_ path: KeyPath<T, IDProperty<T, Value>>) -> Self {
        self.groupBy(SQLColumn(T()[keyPath: path].key.description, table: T.schemaOrAlias))
    }

    func join<From: Model, To: Model, IDValue>(from: KeyPath<From, FieldProperty<From, IDValue>>, to path: KeyPath<To, FieldProperty<To, IDValue>>, method: SQLJoinMethod = .inner) -> Self {
        self.join(To.schemaOrAlias, method: method, on: "\"\(From.schemaOrAlias)\".\"\(From()[keyPath: from].key.description)\"=\"\(To.schemaOrAlias)\".\"\(To()[keyPath: path].key.description)\"")
    }

    func join<From: Model, To: Model, IDValue>(from: KeyPath<From, OptionalFieldProperty<From, IDValue>>, to path: KeyPath<To, FieldProperty<To, IDValue>>, method: SQLJoinMethod = .inner) -> Self {
        self.join(To.schemaOrAlias, method: method, on: "\"\(From.schemaOrAlias)\".\"\(From()[keyPath: from].key.description)\"=\"\(To.schemaOrAlias)\".\"\(To()[keyPath: path].key.description)\"")
    }

    func join<From: Model, To: Model, IDValue>(from: KeyPath<From, OptionalFieldProperty<From, IDValue>>, to path: KeyPath<To, OptionalFieldProperty<To, IDValue>>, method: SQLJoinMethod = .inner) -> Self {
        self.join(To.schemaOrAlias, method: method, on: "\"\(From.schemaOrAlias)\".\"\(From()[keyPath: from].key.description)\"=\"\(To.schemaOrAlias)\".\"\(To()[keyPath: path].key.description)\"")
    }

    func join<From: Model, To: Model, IDValue>(from: KeyPath<From, OptionalFieldProperty<From, IDValue>>, to path: KeyPath<To, IDProperty<To, IDValue>>, method: SQLJoinMethod = .inner) -> Self {
        self.join(To.schemaOrAlias, method: method, on: "\"\(From.schemaOrAlias)\".\"\(From()[keyPath: from].key.description)\"=\"\(To.schemaOrAlias)\".\"\(To()[keyPath: path].key.description)\"")
    }

    func join<From: Model, To: Model, IDValue>(from: KeyPath<From, IDProperty<From, IDValue>>, to path: KeyPath<To, OptionalFieldProperty<To, IDValue>>, method: SQLJoinMethod = .inner) -> Self {
        self.join(To.schemaOrAlias, method: method, on: "\"\(From.schemaOrAlias)\".\"\(From()[keyPath: from].key.description)\"=\"\(To.schemaOrAlias)\".\"\(To()[keyPath: path].key.description)\"")
    }

    func join<From: Model, To: Model, IDValue>(from: KeyPath<From, IDProperty<From, IDValue>>, to path: KeyPath<To, IDProperty<To, IDValue>>, method: SQLJoinMethod = .inner) -> Self {
        self.join(To.schemaOrAlias, method: method, on: "\"\(From.schemaOrAlias)\".\"\(From()[keyPath: from].key.description)\"=\"\(To.schemaOrAlias)\".\"\(To()[keyPath: path].key.description)\"")
    }

    func join<From: Model, To: Model, IDValue>(from: KeyPath<From, FieldProperty<From, IDValue>>, to path: KeyPath<To, IDProperty<To, IDValue>>, method: SQLJoinMethod = .inner) -> Self {
        self.join(To.schemaOrAlias, method: method, on: "\"\(From.schemaOrAlias)\".\"\(From()[keyPath: from].key.description)\"=\"\(To.schemaOrAlias)\".\"\(To()[keyPath: path].key.description)\"")
    }

    func join<From: Model, To: Model, IDValue>(from: KeyPath<From, IDProperty<From, IDValue>>, to path: KeyPath<To, FieldProperty<To, IDValue>>, method: SQLJoinMethod = .inner) -> Self {
        self.join(To.schemaOrAlias, method: method, on: "\"\(From.schemaOrAlias)\".\"\(From()[keyPath: from].key.description)\"=\"\(To.schemaOrAlias)\".\"\(To()[keyPath: path].key.description)\"")
    }

    public func all<A, B>(decoding: A.Type, _ bType: B.Type) -> EventLoopFuture<[(A, B)]>
        where A: Decodable, B: Decodable {
        self.all().flatMapThrowing {
            try $0.map {
                try (
                    $0.decode(model: A.self),
                    $0.decode(model: B.self)
                )
            }
        }
    }
}

public protocol SubjectTestRepositoring: DeleteModelRepository {

    func find(_ id: SubjectTest.ID, or error: Error) -> EventLoopFuture<SubjectTest>

    func create(from content: SubjectTest.Create.Data, by user: User?) throws -> EventLoopFuture<SubjectTest.Create.Response>

    func updateModelWith(id: Int, to data: SubjectTest.Update.Data, by user: User) throws -> EventLoopFuture<SubjectTest.Update.Response>

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
    func enter(test: SubjectTest, with request: SubjectTest.Enter.Request, by user: User) -> EventLoopFuture<TestSession>

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

    func stats(for subject: Subject) throws -> EventLoopFuture<[SubjectTest.DetailedResult]>

}

extension SubjectTest {

    //swiftlint:disable type_body_length
    public struct DatabaseRepository: SubjectTestRepositoring, DatabaseConnectableRepository {

        init(database: Database, repositories: RepositoriesRepresentable) {
            self.database = database
            self.userRepository = repositories.userRepository
            self.subjectRepository = repositories.subjectRepository
            self.testSessionRepository = repositories.testSessionRepository
        }

        public let database: Database

        private let userRepository: UserRepository
        private let subjectRepository: SubjectRepositoring
        private let testSessionRepository: TestSessionRepositoring

        public enum Errors: Error {
            case testIsClosed
            case alreadyEntered(sessionID: TestSession.ID)
            case incorrectPassword
            case testHasNotBeenHeldYet
            case alreadyEnded
        }

        public func deleteModelWith(id: Int, by user: User?) throws -> EventLoopFuture<Void> {
            deleteDatabase(SubjectTest.DatabaseModel.self, modelID: id)
        }

        public func find(_ id: Int) -> EventLoopFuture<SubjectTest?> {
            findDatabaseModel(SubjectTest.DatabaseModel.self, withID: id)
        }

        public func find(_ id: Int, or error: Error) -> EventLoopFuture<SubjectTest> {
            findDatabaseModel(SubjectTest.DatabaseModel.self, withID: id, or: error)
        }

        public func create(from content: SubjectTest.Create.Data, by user: User?) throws -> EventLoopFuture<SubjectTest> {
            guard let user = user else {
                throw Abort(.unauthorized)
            }

            return subjectRepository
                .subjectIDFor(taskIDs: content.tasks)
                .flatMap { subjectID in

                    guard subjectID == content.subjectID else {
                        return self.database.eventLoop.future(error: Abort(.badRequest))
                    }

                    return self.userRepository
                        .isModerator(user: user, subjectID: subjectID)
                        .ifFalse(throw: Abort(.forbidden))
            }.flatMap {
                let test = SubjectTest.DatabaseModel(data: content)

                return test.create(on: self.database)
                    .failableFlatMap {
                        try self
                            .createTask(
                                from: .init(
                                    testID: test.requireID(),
                                    taskIDs: content.tasks
                                ),
                                by: user
                        )
                }
                .flatMapThrowing { try test.content() }
            }
        }

        public func updateModelWith(id: Int, to data: SubjectTest.Update.Data, by user: User) throws -> EventLoopFuture<SubjectTest> {
            return subjectRepository
                .subjectIDFor(taskIDs: data.tasks)
                .failableFlatMap { subjectID in

                    guard subjectID == data.subjectID else {
                        throw Abort(.badRequest)
                    }

                    return self.userRepository
                        .isModerator(user: user, subjectID: subjectID)
                        .ifFalse(throw: Abort(.forbidden))
            }.flatMap {
                self.updateDatabase(SubjectTest.DatabaseModel.self, modelID: id, to: data)
                    .failableFlatMap { test in

                        try self
                            .updateTaskWith(
                                id: test.id,
                                to: data.tasks,
                                by: user
                        )
                        .transform(to: test)
                }
            }
        }

        func createTask(from content: SubjectTest.Pivot.Task.Create.Data, by user: User?) throws -> EventLoopFuture<Void> {
            content.taskIDs.map {
                SubjectTest.Pivot.Task(
                    testID: content.testID,
                    taskID: $0
                )
                .create(on: self.database)
            }
            .flatten(on: database.eventLoop)
        }

        func updateTaskWith(id: Int, to data: SubjectTest.Pivot.Task.Update.Data, by user: User) throws -> EventLoopFuture<Void> {
            SubjectTest.Pivot.Task.query(on: database)
                .filter(\.$test.$id == id)
                .all()
                .flatMap { tasks in
                    data.changes(from: tasks.map { $0.$task.id })
                        .compactMap { change in

                            switch change {
                            case .insert(let taskID):
                                return SubjectTest.Pivot.Task(
                                    testID: id,
                                    taskID: taskID
                                )
                                    .create(on: self.database)
                            case .remove(let taskID):
                                return tasks.first(where: { $0.$task.id == taskID })?
                                    .delete(on: self.database)
                            }
                    }
                    .flatten(on: self.database.eventLoop)
            }
        }

        public func enter(test: SubjectTest, with request: SubjectTest.Enter.Request, by user: User) -> EventLoopFuture<TestSession> {
            guard test.isOpen else {
                return database.eventLoop.future(error: Errors.testIsClosed)
            }
            guard test.password == request.password else {
                return database.eventLoop.future(error: Errors.incorrectPassword)
            }
            return TestSession.DatabaseModel.query(on: database)
                .join(TaskSession.self, on: \TaskSession.$id == \TestSession.DatabaseModel.$id)
                .filter(TaskSession.self, \TaskSession.$user.$id == user.id)
                .filter(\TestSession.DatabaseModel.$test.$id == test.id)
                .first()
                .flatMap { session in

                    if let sessionID = try? session?.requireID() {
                        return self.database.eventLoop.future(error: Errors.alreadyEntered(sessionID: sessionID))
                    }
                    let session = TaskSession(userID: user.id)

                    return session.create(on: self.database)
                        .flatMapThrowing {
                            try TestSession.DatabaseModel(
                                sessionID: session.requireID(),
                                testID: test.id
                            )
                        }
                        .flatMap { session in
                            session.create(on: self.database)
                                .flatMapThrowing { try session.content() }
                    }
            }
        }

        public func open(test: SubjectTest, by user: User) throws -> EventLoopFuture<SubjectTest> {
            return userRepository
                .isModerator(user: user, subjectID: test.subjectID)
                .ifFalse(throw: Abort(.forbidden))
                .flatMap {
                    SubjectTest.DatabaseModel.find(test.id, on: self.database)
                        .unwrap(or: Abort(.badRequest))
                }
                .flatMap { $0.open(on: self.database) }
                .content()
        }

        public func userCompletionStatus(in test: SubjectTest, user: User) throws -> EventLoopFuture<CompletionStatus> {

            userRepository
                .isModerator(user: user, subjectID: test.subjectID)
                .ifFalse(throw: Abort(.forbidden))
                .flatMap {

                    TestSession.DatabaseModel.query(on: self.database)
                        .filter(\.$test.$id == test.id)
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

        func sessionWith(id: TestSession.ID, isOwnedBy userID: User.ID) -> EventLoopFuture<Bool> {
            TaskSession.query(on: database).filter(\.$user.$id == userID).filter(\.$id == id).first().map { $0 != nil }
        }

        public func taskWith(id: Int, in session: TestSessionRepresentable, for user: User) throws -> EventLoopFuture<SubjectTest.MultipleChoiseTaskContent> {

            guard let sessionID = try? session.requireID() else { return database.eventLoop.future(error: Abort(.badRequest)) }

            return sessionWith(id: sessionID, isOwnedBy: user.id)
                .ifFalse(throw: Abort(.forbidden))
                .flatMap {

                    SubjectTest.Pivot.Task.query(on: self.database)
                        .join(parent: \SubjectTest.Pivot.Task.$task)
                        .join(superclass: KognitaModels.MultipleChoiceTask.DatabaseModel.self, with: TaskDatabaseModel.self)
                        .filter(\SubjectTest.Pivot.Task.$test.$id == session.testID)
                        .filter(\SubjectTest.Pivot.Task.$id == id)
                        .first(TaskDatabaseModel.self, KognitaModels.MultipleChoiceTask.DatabaseModel.self)
                        .unwrap(or: Abort(.badRequest))
                        .flatMap { (task, multipleChoiseTask) in

                            guard let taskID = task.id else { return self.database.eventLoop.future(error: Abort(.internalServerError)) }

                            return MultipleChoiseTaskChoise.query(on: self.database)
                                .filter(\MultipleChoiseTaskChoise.$task.$id == taskID)
                                .all()
                                .flatMap { (choices: [MultipleChoiseTaskChoise]) in

                                    return TaskSessionAnswer.query(on: self.database)
                                        .join(MultipleChoiseTaskAnswer.self, on: \MultipleChoiseTaskAnswer.$id == \TaskSessionAnswer.$taskAnswer.$id)
                                        .join(parent: \MultipleChoiseTaskAnswer.$choice)
                                        .filter(\TaskSessionAnswer.$session.$id == sessionID)
                                        .filter(MultipleChoiseTaskChoise.self, \MultipleChoiseTaskChoise.$task.$id == taskID)
                                        .all(MultipleChoiseTaskAnswer.self)
                                        .flatMap { (answers: [MultipleChoiseTaskAnswer]) in

                                            self.multipleChoiceTaskContent(
                                                id: id,
                                                task: task,
                                                multipleChoiceTask: multipleChoiseTask,
                                                choices: choices,
                                                answers: answers,
                                                in: session
                                            )
                                    }
                            }
                    }
            }
        }

        private func multipleChoiceTaskContent(id: Int, task: TaskDatabaseModel, multipleChoiceTask: KognitaModels.MultipleChoiceTask.DatabaseModel, choices: [MultipleChoiseTaskChoise], answers: [MultipleChoiseTaskAnswer], in session: TestSessionRepresentable) -> EventLoopFuture<SubjectTest.MultipleChoiseTaskContent> {

            let answeredChoices = answers.map { $0.$choice.id }

            return SubjectTest.Pivot.Task.query(on: self.database)
                .filter(\.$test.$id == session.testID)
                .all()
                .flatMap { (testTasks: [SubjectTest.Pivot.Task]) in

                    SubjectTest.DatabaseModel
                        .find(session.testID, on: self.database)
                        .unwrap(or: Abort(.internalServerError))
                        .flatMapThrowing { (test: SubjectTest.DatabaseModel) -> SubjectTest.MultipleChoiseTaskContent in

                            try SubjectTest.MultipleChoiseTaskContent(
                                test: test.content(),
                                task: multipleChoiceTask.content(task: task, choices: choices),
                                choises: choices.map { choice in
                                    try MultipleChoiseTaskContent.Choise(
                                        id: choice.requireID(),
                                        choise: choice.choice,
                                        isCorrect: choice.isCorrect,
                                        isSelected: answeredChoices.contains(choice.requireID())
                                    )
                                },
                                testTasks: testTasks.map { testTask in
                                    try AssignedTask(
                                        testTaskID: testTask.requireID(),
                                        isCurrent: testTask.$task.id == id
                                    )
                                }
                            )
                    }
            }
        }

        struct MultipleChoiseTaskAnswerCount: Codable {
            let choiseID: MultipleChoiceTaskChoice.ID
            let numberOfAnswers: Int
        }

        public func results(for test: SubjectTest, user: User) throws -> EventLoopFuture<Results> {
            guard test.endedAt != nil else {
                throw Errors.testHasNotBeenHeldYet
            }

            guard let sql = database as? SQLDatabase else { return database.eventLoop.future(error: Abort(.internalServerError)) }

            return userRepository
                .isModerator(user: user, subjectID: test.subjectID)
                .ifFalse(throw: Abort(.forbidden))
                .flatMap {

                    sql.select()
                        .column(\MultipleChoiseTaskAnswer.$choice.$id)
                        .column(SQLAlias(SQLFunction("COUNT", args: "choiseID"), as: SQLIdentifier("numberOfAnswers")))
                        .from(TestSession.DatabaseModel.schema)
                        .join(from: \TestSession.DatabaseModel.$id, to: \TaskSessionAnswer.$session.$id)
                        .join(from: \TaskSessionAnswer.$id, to: \MultipleChoiseTaskAnswer.$id)
                        .groupBy(\MultipleChoiseTaskAnswer.$choice.$id)
                        .where("testID", .equal, test.id)
                        .all(decoding: MultipleChoiseTaskAnswerCount.self)
                        .flatMap { choiceCount in

                            SubjectTest.Pivot.Task.query(on: self.database)
                                .withDeleted()
                                .join(parent: \SubjectTest.Pivot.Task.$task)
                                .join(MultipleChoiseTaskChoise.self, on: \TaskDatabaseModel.$id == \MultipleChoiseTaskChoise.$task.$id)
                                .filter(\SubjectTest.Pivot.Task.$test.$id == test.id)
                                .all(TaskDatabaseModel.self, MultipleChoiseTaskChoise.self)
                                .failableFlatMap { tasks in

                                    try self.calculateResultStatistics(
                                        for: test,
                                        tasks: tasks,
                                        choiseCount: choiceCount,
                                        user: user
                                    )
                            }
                    }
            }
        }

        private func calculateResultStatistics(
            for test: SubjectTest,
            tasks: [(task: TaskDatabaseModel, choice: MultipleChoiseTaskChoise)],
            choiseCount: [MultipleChoiseTaskAnswerCount],
            user: User
        ) throws -> EventLoopFuture<SubjectTest.Results> {

            guard let heldAt = test.openedAt else {
                throw Errors.testHasNotBeenHeldYet
            }

            var numberOfCorrectAnswers: Double = 0

            let grupedChoiseCount = choiseCount.reduce(into: [MultipleChoiceTaskChoice.ID: Int]()) { dict, choiseCount in
                dict[choiseCount.choiseID] = choiseCount.numberOfAnswers
            }

            let taskResults: [SubjectTest.Results.MultipleChoiseTaskResult] = tasks.group(by: \.task.id)
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
                                choise: choise.choice,
                                numberOfSubmissions: choiseCount,
                                percentage: Double(choiseCount) / Double(totalCount),
                                isCorrect: choise.isCorrect
                            )
                        }
                    )
            }

            return try detailedUserResults(for: test, maxScore: Double(taskResults.count), user: user)
                .flatMap { userResults in

                    TestSession.DatabaseModel.query(on: self.database)
                        .filter(\.$test.$id == test.id)
                        .count()
                        .flatMap { numberOfSessions in

                            Subject.DatabaseModel.find(test.subjectID, on: self.database)
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

            return SubjectTest.DatabaseModel.query(on: database)
                .join(parent: \SubjectTest.DatabaseModel.$subject)
                .join(User.ActiveSubject.self, on: \User.ActiveSubject.$subject.$id == \SubjectTest.DatabaseModel.$subject.$id)
                .filter(\.$openedAt != nil)
                .filter(User.ActiveSubject.self, \User.ActiveSubject.$user.$id == user.id)
                .all(with: \.$subject)
                .flatMap { tests in
                    guard
                        let test = tests.first(where: { $0.isOpen }),
                        let testID = test.id
                    else {
                        return self.database.eventLoop.future(nil)
                    }

                    return TestSession.DatabaseModel.query(on: self.database)
                        .join(TaskSession.self, on: \TaskSession.$id == \TestSession.DatabaseModel.$id)
                        .filter(TaskSession.self, \TaskSession.$user.$id == user.id)
                        .filter(\TestSession.DatabaseModel.$test.$id == testID)
                        .limit(1)
                        .first()
                        .flatMapThrowing { session in
                            try SubjectTest.UserOverview(
                                test: test.content(),
                                subjectName: test.subject.name,
                                subjectID: test.subject.requireID(),
                                hasSubmitted: session?.hasSubmitted ?? false,
                                testSessionID: session?.requireID()
                            )
                    }
            }
        }

        public func currentlyOpenTest(in subject: Subject, user: User) throws -> EventLoopFuture<SubjectTest.UserOverview?> {

            return SubjectTest.DatabaseModel.query(on: database)
                .join(parent: \SubjectTest.DatabaseModel.$subject)
                .join(User.ActiveSubject.self, on: \User.ActiveSubject.$subject.$id == \SubjectTest.DatabaseModel.$subject.$id)
                .filter(\.$openedAt != nil)
                .filter(\.$subject.$id == subject.id)
                .filter(User.ActiveSubject.self, \User.ActiveSubject.$user.$id == user.id)
                .all(with: \.$subject)
                .flatMap { tests in
                    guard
                        let test = tests.first(where: { $0.isOpen }),
                        let testID = test.id
                    else {
                        return self.database.eventLoop.future(nil)
                    }

                    return TestSession.DatabaseModel.query(on: self.database)
                        .join(TaskSession.self, on: \TaskSession.$id == \TestSession.DatabaseModel.$id)
                        .filter(TaskSession.self, \TaskSession.$user.$id == user.id)
                        .filter(\TestSession.DatabaseModel.$test.$id == testID)
                        .limit(1)
                        .first()
                        .flatMapThrowing { session in
                            try SubjectTest.UserOverview(
                                test: test.content(),
                                subjectName: test.subject.name,
                                subjectID: test.subject.requireID(),
                                hasSubmitted: session?.hasSubmitted ?? false,
                                testSessionID: session?.requireID()
                            )
                    }
            }
        }

        public func all(in subject: Subject, for user: User) throws -> EventLoopFuture<[SubjectTest]> {

            userRepository
                .isModerator(user: user, subjectID: subject.id)
                .ifFalse(throw: Abort(.forbidden))
                .flatMap {

                    SubjectTest.DatabaseModel.query(on: self.database)
                        .filter(\.$subject.$id == subject.id)
                        .sort(\.$scheduledAt, .descending)
                        .all()
                        .flatMapEachThrowing { try $0.content() }
            }
        }

        public func taskIDsFor(testID id: SubjectTest.ID) throws -> EventLoopFuture<[Task.ID]> {

            SubjectTest.Pivot.Task.query(on: database)
                .filter(\.$test.$id == id)
                .all()
                .map { rows in
                    return rows.map { $0.$task.id }
            }
        }

        public func firstTaskID(testID: SubjectTest.ID) throws -> EventLoopFuture<Int?> {

            SubjectTest.Pivot.Task
                .query(on: database)
                .filter(\.$test.$id == testID)
                .sort(\.$createdAt, .ascending)
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

            return userRepository
                .isModerator(user: user, subjectID: test.subjectID)
                .ifFalse(throw: Abort(.forbidden))
                .flatMap {
                    SubjectTest.DatabaseModel
                        .find(test.id, on: self.database)
                        .unwrap(or: Abort(.badRequest))
                        .flatMap { test in
                            test.endedAt = .now
                            return test.save(on: self.database)
                    }
            }
            .failableFlatMap {
                try self.createResults(in: test)
            }
        }

        func createResults(in test: SubjectTest) throws -> EventLoopFuture<Void> {

            return TestSession.DatabaseModel.query(on: database)
                .join(from: TestSession.DatabaseModel.self, to: TaskSession.self)
                .filter(\.$test.$id == test.id)
                .filter(\.$submittedAt == nil)
                .all(TestSession.DatabaseModel.self, TaskSession.self)
                .failableFlatMap { sessions in

                    try sessions.map { testSession, taskSession in
                        try self.testSessionRepository.createResult(
                            for: TestSession.TestParameter(
                                session: taskSession,
                                testSession: testSession
                            )
                        )
                        .flatMapErrorThrowing { _ in
                            // Ignoring errors in this case
                        }
                    }.flatten(on: self.database.eventLoop)
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

            guard let sql = database as? SQLDatabase else { return database.eventLoop.future(error: Abort(.internalServerError)) }

            return userRepository
                .isModerator(user: user, subjectID: test.subjectID)
                .ifFalse(throw: Abort(.forbidden))
                .flatMap { _ in

                    SubjectTest.Pivot.Task.query(on: self.database)
                        .filter(\.$test.$id == test.id)
                        .count()
                        .flatMap { count in

                            sql.select()
                                .column(\TaskResult.DatabaseModel.$resultScore, as: "score")
                                .column(\TestSession.DatabaseModel.$id, as: "sessionID")
                                .from(TestSession.DatabaseModel.schema)
                                .join(from: \TestSession.DatabaseModel.$id, to: \TaskResult.DatabaseModel.$session.$id)
                                .where("testID", .equal, test.id)
                                .all(decoding: HistogramQueryResult.self)
                                .map { results in
                                    self.calculateHistogram(from: results, maxScore: count)
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

            guard let sql = database as? SQLDatabase else { return database.eventLoop.future(error: Abort(.internalServerError)) }

            return userRepository
                .isModerator(user: user, subjectID: test.subjectID)
                .ifFalse(throw: Abort(.forbidden))
                .flatMap {

                    return sql.select()
                        .column(\User.DatabaseModel.$email, as: "userEmail")
                        .column(\User.DatabaseModel.$id, as: "userID")
                        .column(\TaskResult.DatabaseModel.$resultScore, as: "score")
                        .from(TaskResult.DatabaseModel.schema)
                        .join(from: \TaskResult.DatabaseModel.$session.$id, to: \TaskSession.$id)
                        .join(from: \TaskSession.$user.$id, to: \User.DatabaseModel.$id)
                        .join(from: \TaskSession.$id, to: \TestSession.DatabaseModel.$id)
                        .where("testID", .equal, test.id)
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

        public func isOpen(testID: SubjectTest.ID) -> EventLoopFuture<Bool> {
            SubjectTest.DatabaseModel.find(testID, on: database)
                .unwrap(or: Abort(.badRequest))
                .map { $0.isOpen }
        }

        public func stats(for subject: Subject) throws -> EventLoopFuture<[SubjectTest.DetailedResult]> {
            return database.eventLoop.future(error: Abort(.notImplemented))
//            return SubjectTest.DatabaseModel.query(on: database)
//                .filter(\.subjectID == subject.id)
//                .filter(\.endedAt != nil)
//                .sort(\.openedAt, .ascending)
//                .all()
//                .flatMap { tests in
//
//                    var lastTest: SubjectTest.DatabaseModel?
//
//                    return try tests.map { test in
//                        defer { lastTest = test }
//                        return try self.results(for: test.content(), lastTest: lastTest?.content())
//                    }
//                    .flatten(on: self.conn)
//            }
        }

        func results(for test: SubjectTest, lastTest: SubjectTest? = nil) throws -> EventLoopFuture<SubjectTest.DetailedResult> {
            return database.eventLoop.future(error: Abort(.notImplemented))
//            SubjectTest.Pivot.Task.query(on: conn)
//                .filter(\.testID == test.id)
//                .count()
//                .flatMap { numberOfTasks in
//
//                    TestSession.DatabaseModel.query(on: self.conn)
//                        .join(\TaskResult.DatabaseModel.sessionID, to: \TestSession.DatabaseModel.id)
//                        .filter(\.testID == test.id)
//                        .decode(TaskResult.DatabaseModel.self)
//                        .all()
//                        .flatMap { testResults in
//
//                            guard let endedAt = test.endedAt else { throw Abort(.badRequest) }
//
//                            var query = PracticeSession.Pivot.Task.query(on: self.conn, withSoftDeleted: true)
//                                .join(\TaskResult.DatabaseModel.sessionID, to: \PracticeSession.Pivot.Task.sessionID)
//                                .join(\Task.id, to: \TaskResult.taskID)
//                                .join(\Subtopic.DatabaseModel.id, to: \Task.subtopicID)
//                                .join(\Topic.DatabaseModel.id, to: \Subtopic.DatabaseModel.topicID)
//                                .filter(\PracticeSession.Pivot.Task.isCompleted == true)
//                                .filter(\Topic.DatabaseModel.subjectId == test.subjectID)
//                                .filter(\PracticeSession.Pivot.Task.createdAt < endedAt)
//                                .decode(TaskResult.DatabaseModel.self)
//
//                            if let lastTest = lastTest, let lastEndedAt = lastTest.endedAt {
//                                query = query.filter(\PracticeSession.Pivot.Task.createdAt > lastEndedAt)
//                            }
//
//                            return query.all()
//                                .map { practiceResults in
//                                    DetailedResult(
//                                        testID: test.id,
//                                        testTitle: test.title,
//                                        maxScore: Double(numberOfTasks),
//                                        results: self.calculateStats(testResults: testResults, practiceResults: practiceResults)
//                                    )
//                            }
//                    }
//            }
        }

        func calculateStats(testResults: [TaskResult.DatabaseModel], practiceResults: [TaskResult.DatabaseModel]) -> [SubjectTest.UserStats] {

            return []
//            let groupedTestResults = testResults.group(by: \.userID.unsafelyUnwrapped)
//            let groupedPracticeResults = practiceResults.group(by: \.userID.unsafelyUnwrapped)
//                .mapValues { results in results.sorted(by: \TaskResult.DatabaseModel.timeUsed.unsafelyUnwrapped) }
//
//            let testScores = groupedTestResults.mapValues { $0.reduce(0) { $0 + $1.resultScore } }
//            let timePracticed = groupedPracticeResults.mapValues { $0.reduce(0) { $0 + ($1.timeUsed ?? 0) } }
//            let medianTime: [User.ID: TimeInterval] = groupedPracticeResults.mapValues { results in
//                if results.count % 2 == 1 {
//                    return results[(results.count - 1)/2].timeUsed ?? 0
//                } else {
//                    return ((results[(results.count)/2].timeUsed ?? 0) + (results[(results.count)/2 + 1].timeUsed ?? 0)) / 2
//                }
//            }
//
//            return testScores.map { userID, testScore in
//
//                SubjectTest.UserStats(
//                    timePracticed: timePracticed[userID] ?? 0,
//                    medianTimePerTask: medianTime[userID] ?? 0,
//                    numberOfTaskExecuted: (groupedPracticeResults[userID] ?? []).count,
//                    testScore: testScore,
//                    userID: userID
//                )
//            }
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
