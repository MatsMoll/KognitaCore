import Vapor
import FluentKit
import FluentSQL

public protocol TestSessionRepresentable {
    var userID: User.ID { get }
    var testID: SubjectTest.ID { get }
    var submittedAt: Date? { get }
    var executedAt: Date? { get }
    var hasSubmitted: Bool { get }

    func requireID() throws -> Int
    func submit(on database: Database) throws -> EventLoopFuture<TestSessionRepresentable>
}

extension TestSessionRepresentable {
    public var hasSubmitted: Bool { submittedAt != nil }
}

public protocol TestSessionRepositoring {
    /// Submits a answer to a task
    /// - Parameters:
    ///   - content: The metadata needed to submit a answer
    ///   - session: The session to submit the answer to
    ///   - user: The user that is submitting the answer
    ///   - conn: The database conenction
    func submit(content: MultipleChoiceTask.Submit, sessionID: TestSession.ID, by user: User) -> EventLoopFuture<Void>

    /// Submits a test session to be evaluated
    /// - Parameters:
    ///   - test: The session to submit
    ///   - user: The user submitting the session
    ///   - conn: The database connection
    func submit(testID: TestSession.ID, by user: User) throws -> EventLoopFuture<Void>

    /// Fetches the results in a test for a given user
    /// - Parameters:
    ///   - test: The test to fetch the results from
    ///   - user: The user to fetch the result for
    ///   - conn: The database connection
    /// - Returns: The results from a session
    func results(in test: TestSession.ID, for user: User) -> EventLoopFuture<KognitaModels.TestSession.Results>

    /// Returns an overview over a test session
    /// - Parameters:
    ///   - test: The session to get a overview over
    ///   - user: The user requesting the overview
    ///   - conn: The database connection
    func overview(in session: TestSessionRepresentable, for user: User) throws -> EventLoopFuture<TestSession.PreSubmitOverview>

    func getSessions(for user: User) -> EventLoopFuture<[TestSession.CompletedOverview]>

    func solutions(for user: User, in session: TestSessionRepresentable, pivotID: Int) throws -> EventLoopFuture<[TaskSolution.Response]>

    func results(in session: TestSessionRepresentable, pivotID: Int) throws -> EventLoopFuture<TestSession.DetailedTaskResult>

    func createResult(for session: TestSessionRepresentable) throws -> EventLoopFuture<Void>

    func testIDFor(id: TestSession.ID) -> EventLoopFuture<SubjectTest.ID>

    func sessionReporesentableWith(id: TestSession.ID) -> EventLoopFuture<TestSessionRepresentable>
}

public enum TestSessionRepositoringError: Error {
    case testIsNotFinnished
}

extension TestSession {
    public struct DatabaseRepository: TestSessionRepositoring, DatabaseConnectableRepository {

        init(database: Database, repositories: RepositoriesRepresentable) {
            self.database = database
            self.repositories = repositories
            self.taskSessionAnswerRepository = TaskSessionAnswer.DatabaseRepository(database: database)
        }

        public let database: Database
        private let repositories: RepositoriesRepresentable

        private var typingTaskRepository: FlashCardTaskRepository { repositories.typingTaskRepository }
        private var multipleChoiseRepository: MultipleChoiseTaskRepository { repositories.multipleChoiceTaskRepository }
        private var userRepository: UserRepository { repositories.userRepository }
        private var taskSolutionRepository: TaskSolutionRepositoring { repositories.taskSolutionRepository }
        private var subjectTestRepository: SubjectTestRepositoring { repositories.subjectTestRepository }
        private var taskResultRepository: TaskResultRepositoring { repositories.taskResultRepository }

        private let taskSessionAnswerRepository: TaskSessionAnswerRepository

        struct OverviewQuery: Codable {
            let question: String
            let testTaskID: SubjectTest.Pivot.Task.IDValue
            let taskID: Task.ID
        }

        struct TaskAnswerTaskIDQuery: Codable {
            let taskID: Task.ID
        }

        public func sessionReporesentableWith(id: TestSession.ID) -> EventLoopFuture<TestSessionRepresentable> {
            TestSession.TestParameter.resolveWith(id, database: database).map { $0 as TestSessionRepresentable }
        }

        public func testIDFor(id: TestSession.ID) -> EventLoopFuture<SubjectTest.ID> {
            TestSession.DatabaseModel.query(on: database).filter(\.$id == id).first().unwrap(or: Abort(.badRequest)).map { $0.$test.id }
        }

        public func overview(in session: TestSessionRepresentable, for user: User) throws -> EventLoopFuture<TestSession.PreSubmitOverview> {
            guard session.userID == user.id else {
                throw Abort(.forbidden)
            }

            guard let sql = database as? SQLDatabase, let sessionID = try? session.requireID() else {
                return database.eventLoop.future(error: Abort(.internalServerError))
            }

            return SubjectTest.DatabaseModel.find(session.testID, on: self.database)
                .unwrap(or: Abort(.badRequest))
                .flatMap { test in

                    sql.select()
                        .column(\TaskDatabaseModel.$id, as: "taskID")
                        .column(\TaskDatabaseModel.$question, as: "question")
                        .column(\SubjectTest.Pivot.Task.$id, as: "testTaskID")
                        .from(SubjectTest.Pivot.Task.schema)
                        .join(parent: \SubjectTest.Pivot.Task.$task)
                        .where("testID", .equal, session.testID)
                        .all(decoding: OverviewQuery.self)
                        .flatMap { tasks in

                            TaskSessionAnswer.query(on: self.database)
                                .join(MultipleChoiseTaskAnswer.self, on: \MultipleChoiseTaskAnswer.$id == \TaskSessionAnswer.$taskAnswer.$id)
                                .join(parent: \MultipleChoiseTaskAnswer.$choice)
                                .filter(\TaskSessionAnswer.$session.$id == sessionID)
                                .all(MultipleChoiseTaskChoise.self, \MultipleChoiseTaskChoise.$task.$id)
                                .flatMapThrowing { taskIDs in

                                    return try TestSession.PreSubmitOverview(
                                        sessionID: sessionID,
                                        test: test.content(),
                                        tasks: tasks.map { task in
                                            return TestSession.PreSubmitOverview.TaskStatus(
                                                testTaskID: task.testTaskID,
                                                question: task.question,
                                                isAnswered: taskIDs.contains(where: { $0 == task.taskID })
                                            )
                                        }
                                    )
                            }
                    }
            }
        }

        public func submit(content: TypingTask.Submit, for session: TestSessionRepresentable, by user: User) throws -> EventLoopFuture<Void> {
            throw Abort(.notImplemented)
//            guard user.id == session.userID else {
//                throw Abort(.forbidden)
//            }
//            guard session.submittedAt == nil else {
//                throw Abort(.badRequest)
//            }
//            return SubjectTest.DatabaseModel.find(session.testID, on: conn)
//                .unwrap(or: Abort(.badRequest))
//                .flatMap { test in
//                    guard test.isOpen else {
//                        throw SubjectTest.DatabaseRepository.Errors.testIsClosed
//                    }
//                    return self.update(answer: content, for: session, by: user)
//                        .catchFlatMap { _ in
//
//                            self.flashCard(at: content.taskIndex)
//                                .flatMap { task in
//
//                                    self.typingTaskRepository
//                                        .createAnswer(for: task, with: content)
//                                        .flatMap { answer in
//
//                                            try self.save(answer: answer, to: session.requireID())
//                                    }
//                            }
//                    }
//            }
        }

        public func submit(content: MultipleChoiceTask.Submit, sessionID: TestSession.ID, by user: User) -> EventLoopFuture<Void> {
            TestSession.TestParameter.resolveWith(sessionID, database: database)
                .flatMap { test in
                    self.submit(content: content, for: test, by: user)
            }
        }

        public func submit(content: MultipleChoiceTask.Submit, for session: TestSessionRepresentable, by user: User) -> EventLoopFuture<Void> {
            guard user.id == session.userID else {
                return database.eventLoop.future(error: Abort(.forbidden))
            }
            guard session.submittedAt == nil else {
                return database.eventLoop.future(error: Abort(.badRequest))
            }
            return SubjectTest.DatabaseModel.find(session.testID, on: database)
                .unwrap(or: Abort(.badRequest))
                .flatMap { test in
                    guard test.isOpen else {
                        return self.database.eventLoop.future(error: SubjectTest.DatabaseRepository.Errors.testIsClosed)
                    }
                    return self.choisesAt(index: content.taskIndex)
                        .flatMap { choises in
                            guard choises.isEmpty == false else {
                                return self.database.eventLoop.future(error: Abort(.badRequest))
                            }
                            let choisesIDs = Set(choises.compactMap { $0.id })

                            guard content.choises.filter({ choisesIDs.contains($0) }).isEmpty == false else {
                                return self.database.eventLoop.future(error: Abort(.badRequest))
                            }
                            return self.update(answer: content, for: session, by: user)
                                .flatMapError { _ in
                                    do {
                                        return try self.multipleChoiseRepository
                                            .create(answer: content, sessionID: session.requireID())
                                            .transform(to: ())
                                    } catch {
                                        return self.database.eventLoop.future(error: error)
                                    }
                            }
                    }
            }
        }

        func update(answer content: MultipleChoiceTask.Submit, for session: TestSessionRepresentable, by user: User) -> EventLoopFuture<Void> {

            guard let sessionID = try? session.requireID() else { return database.eventLoop.future(error: Abort(.internalServerError)) }

            return TestSession.DatabaseModel.query(on: database)
                .join(TaskSessionAnswer.self, on: \TaskSessionAnswer.$session.$id == \TestSession.DatabaseModel.$id)
                .join(parent: \TaskSessionAnswer.$taskAnswer)
                .join(superclass: MultipleChoiseTaskAnswer.self, with: TaskAnswer.self)
                .join(parent: \MultipleChoiseTaskAnswer.$choice)
                .join(SubjectTest.Pivot.Task.self, on: \SubjectTest.Pivot.Task.$task.$id == \MultipleChoiseTaskChoise.$task.$id)
                .filter(\TestSession.DatabaseModel.$id == sessionID)
                .filter(SubjectTest.Pivot.Task.self, \SubjectTest.Pivot.Task.$id == content.taskIndex)
                .all(MultipleChoiseTaskAnswer.self, TaskAnswer.self)
                .failableFlatMap { answers in
                    guard answers.isEmpty == false else {
                        return self.database.eventLoop.future(error: Abort(.badRequest))
                    }
                    let choisesIDs = answers.map { $0.0.$choice.id }
                    return try content.choises
                        .changes(from: choisesIDs)
                        .compactMap { change in
                            switch change {
                            case .insert(let choiseID):
                                return try self.multipleChoiseRepository
                                    .createAnswer(choiseID: choiseID, sessionID: session.requireID())
                                    .transform(to: ())
                            case .remove(let choiseID):
                                return answers.first(where: { $0.0.$choice.id == choiseID })?.1
                                    .delete(on: self.database)
                            }
                    }
                    .flatten(on: self.database.eventLoop)
            }
        }

        func update(answer content: TypingTask.Submit, for session: TestSessionRepresentable, by user: User) -> EventLoopFuture<Void> {
            return database.eventLoop.future(error: Abort(.notImplemented))
//            return conn.databaseConnection(to: .psql)
//                .flatMap { psqlConn in
//
//                    return psqlConn.select()
//                        .all(table: FlashCardAnswer.self)
//                        .from(SubjectTest.Pivot.Task.self)
//                        .join(\SubjectTest.Pivot.Task.taskID, to: \SubjectTest.DatabaseModel.id)
//                        .join(\SubjectTest.DatabaseModel.id, to: \TestSession.DatabaseModel.testID)
//                        .join(\TestSession.DatabaseModel.id, to: \TaskSession.id)
//                        .join(\TestSession.DatabaseModel.id, to: \TaskSessionAnswer.sessionID, method: .left)
//                        .join(\TaskSessionAnswer.taskAnswerID, to: \FlashCardAnswer.id, method: .left)
//                        .where(\TaskSession.userID == user.id)
//                        .orderBy(\SubjectTest.Pivot.Task.createdAt, .ascending)
//                        .where(\SubjectTest.Pivot.Task.id == content.taskIndex)
//                        .first(decoding: FlashCardAnswer?.self)
//                        .unwrap(or: Abort(.badRequest))
//                        .flatMap { answer in
//                            answer.answer = content.answer
//                            return answer.save(on: self.conn)
//                                .transform(to: ())
//                    }
//            }
        }

        func save(answer: TaskAnswer, to sessionID: TestSession.ID) throws -> EventLoopFuture<Void> {
            return try TaskSessionAnswer(
                sessionID: sessionID,
                taskAnswerID: answer.requireID()
            )
            .create(on: database)
        }

        func flashCard(at index: Int) -> EventLoopFuture<FlashCardTask> {
            return database.eventLoop.future(error: Abort(.notImplemented))
//            SubjectTest.Pivot.Task
//                .query(on: conn)
//                .join(\FlashCardTask.id, to: \SubjectTest.Pivot.Task.taskID)
//                .sort(\.createdAt, .ascending)
//                .range(lower: index - 1, upper: index)
//                .decode(FlashCardTask.self)
//                .all()
//                .map { tasks in
//                    guard let task = tasks.first else {
//                        throw Abort(.badRequest)
//                    }
//                    return task
//            }
        }

        func choisesAt(index: Int) -> EventLoopFuture<[MultipleChoiseTaskChoise]> {
            SubjectTest.Pivot.Task.query(on: database)
                .filter(\.$id == index)
                .join(MultipleChoiseTaskChoise.self, on: \MultipleChoiseTaskChoise.$task.$id == \SubjectTest.Pivot.Task.$task.$id)
                .all(MultipleChoiseTaskChoise.self)
        }

        public func submit(testID: TestSession.ID, by user: User) throws -> EventLoopFuture<Void> {
            TestSession.TestParameter.resolveWith(testID, database: database)
                .failableFlatMap { test in
                    guard test.submittedAt == nil else {
                        return self.database.eventLoop.future(error: Abort(.badRequest))
                    }
                    guard test.userID == user.id else {
                        return self.database.eventLoop.future(error: Abort(.forbidden))
                    }

                    return try self.createResult(for: test)
            }
        }

        public func createResult(for session: TestSessionRepresentable) throws -> EventLoopFuture<Void> {

            return try session.submit(on: database)
                .failableFlatMap { _ in
                    try TaskSessionAnswer.query(on: self.database)
                        .join(parent: \TaskSessionAnswer.$taskAnswer)
                        .join(superclass: MultipleChoiseTaskAnswer.self, with: TaskAnswer.self)
                        .join(parent: \MultipleChoiseTaskAnswer.$choice)
                        .filter(\TaskSessionAnswer.$session.$id == session.requireID())
                        .all(MultipleChoiseTaskChoise.self)

            }.flatMap { choices in
                choices.group(by: \.$task.id)
                    .map { taskID, choises in

                        self.multipleChoiseRepository
                            .correctChoisesFor(taskID: taskID)
                            .flatMapThrowing { correctChoises in

                                try self.multipleChoiseRepository
                                    .evaluate(choises.map { try $0.requireID() }, agenst: correctChoises)
                                    .representableWith(taskID: taskID)
                        }
                }
                .flatten(on: self.database.eventLoop)
            }
            .failableFlatMap { results in
                try results.map { result in
                    try self.taskResultRepository
                        .createResult(from: result, userID: session.userID, with: session.requireID())
                }
                .flatten(on: self.database.eventLoop)
            }
            .transform(to: ())
        }

        public func results(in sessionID: TestSession.ID, for user: User) -> EventLoopFuture<KognitaModels.TestSession.Results> {
            TestSession.TestParameter.resolveWith(sessionID, database: database)
                .flatMap { session in
                    self.results(in: session, for: user)
            }
        }
        func results(in session: TestSessionRepresentable, for user: User) -> EventLoopFuture<KognitaModels.TestSession.Results> {

            guard session.userID == user.id else {
                return database.eventLoop.future(error: Abort(.forbidden))
            }
            guard let sessionID = try? session.requireID() else { return database.eventLoop.future(error: Abort(.internalServerError)) }

            return TaskResult.DatabaseModel.query(on: database)
                .join(TestSession.DatabaseModel.self, on: \TestSession.DatabaseModel.$id == \TaskResult.DatabaseModel.$session.$id)
                .join(parent: \TestSession.DatabaseModel.$test)
                .filter(TestSession.DatabaseModel.self, \TestSession.DatabaseModel.$id == sessionID)
                .all(SubjectTest.DatabaseModel.self, TaskResult.DatabaseModel.self)
                .flatMap { results in

                    guard
                        let test = results.first?.0,
                        let testID = test.id,
                        let endedAt = session.submittedAt,
                        let startedAt = session.executedAt
                    else {
                        return self.database.eventLoop.future(error: Abort(.internalServerError))
                    }

                    return SubjectTest.Pivot.Task.query(on: self.database)
                        .withDeleted()
                        .join(parent: \SubjectTest.Pivot.Task.$task)
                        .join(parent: \TaskDatabaseModel.$subtopic)
                        .join(parent: \Subtopic.DatabaseModel.$topic)
                        .filter(\.$test.$id == testID)
                        .all(SubjectTest.Pivot.Task.self, TaskDatabaseModel.self, Topic.DatabaseModel.self)
                        .flatMap { tasks in

                            // Registrating the score for a given task
                            let taskResults = results.reduce(
                                into: [Task.ID: Double]()
                            ) { taskResults, result in
                                taskResults[result.1.$task.id] = result.1.resultScore
                            }

                            guard let subjectID = tasks.first?.2.$subject.id else {
                                return self.database.eventLoop.future(error: Abort(.internalServerError))
                            }

                            return self.userRepository
                                .canPractice(user: user, subjectID: subjectID)
                                .map { canPractice in
                                    Results(
                                        testTitle: test.title,
                                        endedAt: endedAt,
                                        testIsOpen: test.isOpen,
                                        executedAt: startedAt,
                                        shouldPresentDetails: test.isTeamBasedLearning == false,
                                        subjectID: subjectID,
                                        canPractice: canPractice,
                                        topicResults: tasks.group(by: \.2.id) // Grouping by topic id
                                            .compactMap { (id, topicTasks) in

                                                guard
                                                    let topic = topicTasks.first?.2,
                                                    let topicID = id
                                                else {
                                                    return nil
                                                }

                                                return Results.Topic(
                                                    id: topicID,
                                                    name: topic.name,
                                                    taskResults: topicTasks.map { task in
                                                        // Calculating the score for a given task and defaulting to 0 in score
                                                        Results.Task(
                                                            pivotID: task.0.id ?? 0,
                                                            question: task.1.question,
                                                            score: taskResults[task.1.id ?? 0] ?? 0
                                                        )
                                                    }
                                                )
                                        }
                                    )
                            }
                    }
            }
        }

        public func getSessions(for user: User) -> EventLoopFuture<[TestSession.CompletedOverview]> {

            guard let sql = database as? SQLDatabase else {
                return database.eventLoop.future(error: Abort(.internalServerError))
            }

            return sql.select()
                .column(\Subject.DatabaseModel.$name, as: "subjectName")
                .column(\Subject.DatabaseModel.$id, as: "subjectID")
                .column(\TestSession.DatabaseModel.$id, as: "id")
                .column(\TestSession.DatabaseModel.$createdAt, as: "createdAt")
                .column(\TestSession.DatabaseModel.$submittedAt, as: "endedAt")
                .column(\SubjectTest.DatabaseModel.$title, as: "testTitle")
                .from(TestSession.DatabaseModel.schema)
                .join(from: \TestSession.DatabaseModel.$id, to: \TaskSession.$id)
                .join(parent: \TestSession.DatabaseModel.$test)
                .join(parent: \SubjectTest.DatabaseModel.$subject)
                .where(SQLRaw("\"endedAt\" IS NOT NULL"))
                .where("userID", .equal, user.id)
                .all(decoding: TestSession.CompletedOverview.self)
        }

        public func solutions(for user: User, in session: TestSessionRepresentable, pivotID: Int) throws -> EventLoopFuture<[TaskSolution.Response]> {

            guard
                session.hasSubmitted,
                user.id == session.userID
            else {
                throw Abort(.forbidden)
            }

            return SubjectTest.Pivot.Task.find(pivotID, on: database)
                .unwrap(or: Abort(.badRequest))
                .failableFlatMap { task in
                    guard task.$test.id == session.testID else { throw Abort(.badRequest) }
                    return self.taskSolutionRepository.solutions(for: task.$task.id, for: user)
            }
        }

        public func results(in session: TestSessionRepresentable, pivotID: Int) throws -> EventLoopFuture<TestSession.DetailedTaskResult> {

            guard session.hasSubmitted else { throw Abort(.badRequest) }

            return self.subjectTestRepository
                .isOpen(testID: session.testID)
                .ifTrue(throw: TestSessionRepositoringError.testIsNotFinnished)
                .flatMap {

                    SubjectTest.Pivot.Task.query(on: self.database)
                        .withDeleted()
                        .join(parent: \SubjectTest.Pivot.Task.$task)
                        .join(from: TaskDatabaseModel.self, to: MultipleChoiceTask.DatabaseModel.self)
                        .filter(\.$id == pivotID)
                        .filter(\.$test.$id == session.testID)
                        .first(SubjectTest.Pivot.Task.self, TaskDatabaseModel.self, MultipleChoiceTask.DatabaseModel.self)
                        .unwrap(or: Abort(.badRequest))
                        .failableFlatMap { (subjectTask, task, multipleChoice) in

                            return try self.multipleChoiseRepository
                                .multipleChoiseAnswers(in: session.requireID(), taskID: subjectTask.$task.id)
                                .flatMapThrowing { choices in

                                    try TestSession.DetailedTaskResult(
                                        taskID: subjectTask.$task.id,
                                        description: task.description,
                                        question: task.question,
                                        isMultipleSelect: multipleChoice.isMultipleSelect,
                                        testSessionID: session.requireID(),
                                        choises: choices.map { $0.multipleChoiceTaskChoice },
                                        selectedChoises: choices.filter { $0.wasSelected }.map { $0.id }
                                    )
                            }
                    }
            }
        }
    }
}
