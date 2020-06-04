import Vapor
import FluentSQL
import FluentPostgreSQL

public protocol TestSessionRepresentable {
    var userID: User.ID { get }
    var testID: SubjectTest.ID { get }
    var submittedAt: Date? { get }
    var executedAt: Date? { get }
    var hasSubmitted: Bool { get }

    func requireID() throws -> Int
    func submit(on conn: DatabaseConnectable) throws -> EventLoopFuture<TestSessionRepresentable>
}

extension TestSessionRepresentable {
    public var hasSubmitted: Bool { submittedAt != nil }
}

extension TestSession {
    public struct DetailedTaskResult: Content {

        public let taskID: Task.ID
        public let description: String?
        public let question: String
        public let isMultipleSelect: Bool
        public let testSessionID: TestSession.ID
        public let choises: [MultipleChoiseTaskChoise]
        public let selectedChoises: [MultipleChoiseTaskChoise.ID]
    }
}

public protocol TestSessionRepositoring {
    /// Submits a answer to a task
    /// - Parameters:
    ///   - content: The metadata needed to submit a answer
    ///   - session: The session to submit the answer to
    ///   - user: The user that is submitting the answer
    ///   - conn: The database conenction
    func submit(content: MultipleChoiseTask.Submit, for session: TestSessionRepresentable, by user: User) throws -> EventLoopFuture<Void>

    /// Submits a test session to be evaluated
    /// - Parameters:
    ///   - test: The session to submit
    ///   - user: The user submitting the session
    ///   - conn: The database connection
    func submit(test: TestSessionRepresentable, by user: User) throws -> EventLoopFuture<Void>

    /// Fetches the results in a test for a given user
    /// - Parameters:
    ///   - test: The test to fetch the results from
    ///   - user: The user to fetch the result for
    ///   - conn: The database connection
    /// - Returns: The results from a session
    func results(in test: TestSessionRepresentable, for user: User) throws -> EventLoopFuture<KognitaContent.TestSession.Results>

    /// Returns an overview over a test session
    /// - Parameters:
    ///   - test: The session to get a overview over
    ///   - user: The user requesting the overview
    ///   - conn: The database connection
    func overview(in session: TestSessionRepresentable, for user: User) throws -> EventLoopFuture<TestSession.Overview>

    func getSessions(for user: User) throws -> EventLoopFuture<[TestSession.HighOverview]>

    func solutions(for user: User, in session: TestSessionRepresentable, pivotID: Int) throws -> EventLoopFuture<[TaskSolution.Response]>

    func results(in session: TestSessionRepresentable, pivotID: Int) throws -> EventLoopFuture<TestSession.DetailedTaskResult>

    func createResult(for session: TestSessionRepresentable) throws -> EventLoopFuture<Void>
}

public enum TestSessionRepositoringError: Error {
    case testIsNotFinnished
}

extension TestSession {
    public struct DatabaseRepository: TestSessionRepositoring, DatabaseConnectableRepository {

        typealias DatabaseModel = TestSession

        public let conn: DatabaseConnectable

        private var typingTaskRepository: some FlashCardTaskRepository { FlashCardTask.DatabaseRepository(conn: conn) }
        private var multipleChoiseRepository: some MultipleChoiseTaskRepository { MultipleChoiseTask.DatabaseRepository(conn: conn) }
        private var userRepository: some UserRepository { User.DatabaseRepository(conn: conn) }
        private var taskSolutionRepository: some TaskSolutionRepositoring { TaskSolution.DatabaseRepository(conn: conn) }
        private var taskSessionAnswerRepository: TaskSessionAnswerRepository { TaskSessionAnswer.DatabaseRepository(conn: conn) }
        private var subjectTestRepository: some SubjectTestRepositoring { SubjectTest.DatabaseRepository(conn: conn) }

        struct OverviewQuery: Codable {
            let question: String
            let testTaskID: SubjectTest.Pivot.Task.ID
            let taskID: Task.ID
        }

        struct TaskAnswerTaskIDQuery: Codable {
            let taskID: Task.ID
        }

        public func overview(in session: TestSessionRepresentable, for user: User) throws -> EventLoopFuture<TestSession.Overview> {
            guard session.userID == user.id else {
                throw Abort(.forbidden)
            }

            return conn.databaseConnection(to: .psql)
                .flatMap { conn in

                    return conn.select()
                        .all(table: SubjectTest.DatabaseModel.self)
                        .column(\Task.id, as: "taskID")
                        .column(\Task.question, as: "question")
                        .column(\SubjectTest.Pivot.Task.id, as: "testTaskID")
                        .from(SubjectTest.Pivot.Task.self)
                        .join(\SubjectTest.Pivot.Task.taskID, to: \Task.id)
                        .join(\SubjectTest.Pivot.Task.testID, to: \SubjectTest.DatabaseModel.id)
                        .where(\SubjectTest.DatabaseModel.id == session.testID)
                        .all(decoding: OverviewQuery.self, SubjectTest.DatabaseModel.self)
                        .flatMap { tasks in

                            try conn.select()
                                .column(\MultipleChoiseTaskChoise.taskId, as: "taskID")
                                .from(TestSession.DatabaseModel.self)
                                .join(\TestSession.DatabaseModel.id, to: \TaskSessionAnswer.sessionID)
                                .join(\TaskSessionAnswer.taskAnswerID, to: \MultipleChoiseTaskAnswer.id)
                                .join(\MultipleChoiseTaskAnswer.choiseID, to: \MultipleChoiseTaskChoise.id)
                                .where(\TestSession.DatabaseModel.id == session.requireID())
                                .all(decoding: TaskAnswerTaskIDQuery.self)
                                .map { taskIDs in

                                    guard let test = tasks.first?.1 else {
                                        throw Abort(.internalServerError)
                                    }

                                    return try TestSession.Overview(
                                        sessionID: session.requireID(),
                                        test: test.content(),
                                        tasks: tasks.map { task in
                                            return TestSession.Overview.TaskStatus(
                                                testTaskID: task.0.testTaskID,
                                                question: task.0.question,
                                                isAnswered: taskIDs.contains(where: { $0.taskID == task.0.taskID })
                                            )
                                        }
                                    )
                            }
                    }
            }
        }

        public func submit(content: FlashCardTask.Submit, for session: TestSessionRepresentable, by user: User) throws -> EventLoopFuture<Void> {
            guard user.id == session.userID else {
                throw Abort(.forbidden)
            }
            guard session.submittedAt == nil else {
                throw Abort(.badRequest)
            }
            return SubjectTest.DatabaseModel.find(session.testID, on: conn)
                .unwrap(or: Abort(.badRequest))
                .flatMap { test in
                    guard test.isOpen else {
                        throw SubjectTest.DatabaseRepository.Errors.testIsClosed
                    }
                    return self.update(answer: content, for: session, by: user)
                        .catchFlatMap { _ in

                            self.flashCard(at: content.taskIndex)
                                .flatMap { task in

                                    self.typingTaskRepository
                                        .createAnswer(for: task, with: content)
                                        .flatMap { answer in

                                            try self.save(answer: answer, to: session.requireID())
                                    }
                            }
                    }
            }
        }

        public func submit(content: MultipleChoiseTask.Submit, for session: TestSessionRepresentable, by user: User) throws -> EventLoopFuture<Void> {
            guard user.id == session.userID else {
                throw Abort(.forbidden)
            }
            guard session.submittedAt == nil else {
                throw Abort(.badRequest)
            }
            return SubjectTest.DatabaseModel.find(session.testID, on: conn)
                .unwrap(or: Abort(.badRequest))
                .flatMap { test in
                    guard test.isOpen else {
                        throw SubjectTest.DatabaseRepository.Errors.testIsClosed
                    }
                    return self.choisesAt(index: content.taskIndex)
                        .flatMap { choises in
                            guard choises.isEmpty == false else {
                                throw Abort(.badRequest)
                            }
                            let choisesIDs = Set(choises.map { $0.id })
                            guard content.choises.filter({ choisesIDs.contains($0) }).isEmpty == false else {
                                throw Abort(.badRequest)
                            }
                            return self.update(answer: content, for: session, by: user)
                                .catchFlatMap { _ in

                                    return try self.multipleChoiseRepository
                                        .create(answer: content, sessionID: session.requireID())
                                        .transform(to: ())
                            }
                    }
            }
        }

        func update(answer content: MultipleChoiseTask.Submit, for session: TestSessionRepresentable, by user: User) -> EventLoopFuture<Void> {
            return conn.databaseConnection(to: .psql)
                .flatMap { psqlConn in

                    return try psqlConn.select()
                        .all(table: MultipleChoiseTaskAnswer.self)
                        .all(table: TaskAnswer.self)
                        .from(TestSession.DatabaseModel.self)
                        .join(\TestSession.DatabaseModel.id, to: \TaskSessionAnswer.sessionID)
                        .join(\TaskSessionAnswer.taskAnswerID, to: \TaskAnswer.id)
                        .join(\TaskAnswer.id, to: \MultipleChoiseTaskAnswer.id)
                        .join(\MultipleChoiseTaskAnswer.choiseID, to: \MultipleChoiseTaskChoise.id)
                        .join(\MultipleChoiseTaskChoise.taskId, to: \SubjectTest.Pivot.Task.taskID)
                        .where(\TestSession.DatabaseModel.id == session.requireID())
                        .where(\SubjectTest.Pivot.Task.id == content.taskIndex)
                        .all(decoding: MultipleChoiseTaskAnswer.self, TaskAnswer.self)
                        .flatMap { answers in
                            guard answers.isEmpty == false else {
                                throw Abort(.badRequest)
                            }
                            let choisesIDs = answers.map { $0.0.choiseID }
                            return try content.choises
                                .changes(from: choisesIDs)
                                .compactMap { change in
                                    switch change {
                                    case .insert(let choiseID):
                                        return try self.multipleChoiseRepository
                                            .createAnswer(choiseID: choiseID, sessionID: session.requireID())
                                            .transform(to: ())
                                    case .remove(let choiseID):
                                        return answers.first(where: { $0.0.choiseID == choiseID })?.1
                                            .delete(on: self.conn)
                                    }
                            }
                            .flatten(on: self.conn)
                    }
            }
        }

        func update(answer content: FlashCardTask.Submit, for session: TestSessionRepresentable, by user: User) -> EventLoopFuture<Void> {
            return conn.databaseConnection(to: .psql)
                .flatMap { psqlConn in

                    return psqlConn.select()
                        .all(table: FlashCardAnswer.self)
                        .from(SubjectTest.Pivot.Task.self)
                        .join(\SubjectTest.Pivot.Task.taskID, to: \SubjectTest.DatabaseModel.id)
                        .join(\SubjectTest.DatabaseModel.id, to: \TestSession.DatabaseModel.testID)
                        .join(\TestSession.DatabaseModel.id, to: \TaskSession.id)
                        .join(\TestSession.DatabaseModel.id, to: \TaskSessionAnswer.sessionID, method: .left)
                        .join(\TaskSessionAnswer.taskAnswerID, to: \FlashCardAnswer.id, method: .left)
                        .where(\TaskSession.userID == user.id)
                        .orderBy(\SubjectTest.Pivot.Task.createdAt, .ascending)
                        .where(\SubjectTest.Pivot.Task.id == content.taskIndex)
                        .first(decoding: FlashCardAnswer?.self)
                        .unwrap(or: Abort(.badRequest))
                        .flatMap { answer in
                            answer.answer = content.answer
                            return answer.save(on: self.conn)
                                .transform(to: ())
                    }
            }
        }

        func save(answer: TaskAnswer, to sessionID: TestSession.ID) throws -> EventLoopFuture<Void> {
            return try TaskSessionAnswer(
                sessionID: sessionID,
                taskAnswerID: answer.requireID()
            )
            .create(on: conn)
            .transform(to: ())
        }

        func flashCard(at index: Int) -> EventLoopFuture<FlashCardTask> {
            SubjectTest.Pivot.Task
                .query(on: conn)
                .join(\FlashCardTask.id, to: \SubjectTest.Pivot.Task.taskID)
                .sort(\.createdAt, .ascending)
                .range(lower: index - 1, upper: index)
                .decode(FlashCardTask.self)
                .all()
                .map { tasks in
                    guard let task = tasks.first else {
                        throw Abort(.badRequest)
                    }
                    return task
            }
        }

        func choisesAt(index: Int) -> EventLoopFuture<[MultipleChoiseTaskChoise]> {
            SubjectTest.Pivot.Task.query(on: conn)
                .filter(\.id == index)
                .join(\MultipleChoiseTaskChoise.taskId, to: \SubjectTest.Pivot.Task.taskID)
                .decode(MultipleChoiseTaskChoise.self)
                .all()
        }

        public func submit(test: TestSessionRepresentable, by user: User) throws -> EventLoopFuture<Void> {
            guard test.submittedAt == nil else {
                throw Abort(.badRequest)
            }
            guard test.userID == user.id else {
                throw Abort(.forbidden)
            }

            return try createResult(for: test)
        }

        public func createResult(for session: TestSessionRepresentable) throws -> EventLoopFuture<Void> {
            return try session.submit(on: conn)
                .flatMap { _ in
                    self.conn.databaseConnection(to: .psql)
                        .flatMap { psqlConn in

                            try psqlConn.select()
                                .all(table: MultipleChoiseTaskChoise.self)
                                .from(TaskSessionAnswer.self)
                                .join(\TaskSessionAnswer.taskAnswerID, to: \TaskAnswer.id)
                                .join(\TaskAnswer.id, to: \MultipleChoiseTaskAnswer.id)
                                .join(\MultipleChoiseTaskAnswer.choiseID, to: \MultipleChoiseTaskChoise.id)
                                .where(\TaskSessionAnswer.sessionID == session.requireID())
                                .all(decoding: MultipleChoiseTaskChoise.self)
                                .flatMap { choises in
                                    choises.group(by: \.taskId)
                                        .map { taskID, choises in

                                            self.multipleChoiseRepository
                                                .correctChoisesFor(taskID: taskID)
                                                .map { correctChoises in

                                                    try self.multipleChoiseRepository
                                                        .evaluate(choises.map { try $0.requireID() }, agenst: correctChoises)
                                                        .representableWith(taskID: taskID)
                                            }
                                    }
                                    .flatten(on: psqlConn)
                            }
                            .flatMap { results in
                                try results.map { result in
                                    try TaskResult.DatabaseRepository
                                        .createResult(from: result, userID: session.userID, with: session.requireID(), on: psqlConn)
                                }
                                .flatten(on: psqlConn)
                            }
                            .transform(to: ())
                    }
            }
        }

        public func results(in session: TestSessionRepresentable, for user: User) throws -> EventLoopFuture<KognitaContent.TestSession.Results> {

            guard session.userID == user.id else {
                throw Abort(.forbidden)
            }

            return try TestSession.DatabaseModel.query(on: conn)
                .join(\SubjectTest.DatabaseModel.id, to: \TestSession.DatabaseModel.testID)
                .join(\TaskResult.DatabaseModel.sessionID, to: \TestSession.DatabaseModel.id)
                .filter(\TestSession.DatabaseModel.id == session.requireID())
                .decode(SubjectTest.DatabaseModel.self)
                .alsoDecode(TaskResult.DatabaseModel.self)
                .all()
                .flatMap { results in

                    guard
                        let test = results.first?.0,
                        let endedAt = session.submittedAt,
                        let startedAt = session.executedAt
                    else {
                        throw Abort(.internalServerError)
                    }

                    return try SubjectTest.Pivot.Task.query(on: self.conn)
                        .join(\Task.id, to: \SubjectTest.Pivot.Task.taskID)
                        .join(\Subtopic.DatabaseModel.id, to: \Task.subtopicID)
                        .join(\Topic.DatabaseModel.id, to: \Subtopic.DatabaseModel.topicId)
                        .filter(\.testID == test.requireID())
                        .alsoDecode(Task.self)
                        .alsoDecode(Topic.DatabaseModel.self)
                        .all()
                        .flatMap { tasks in

                            // Registrating the score for a given task
                            let taskResults = results.reduce(
                                into: [Task.ID: Double]()
                            ) { taskResults, result in
                                taskResults[result.1.taskID] = result.1.resultScore
                            }

                            guard let subjectID = tasks.first?.1.subjectId else {
                                throw Abort(.internalServerError)
                            }

                            return try self.userRepository
                                .canPractice(user: user, subjectID: subjectID)
                                .map { true }
                                .catchMap { _ in false }
                            .map { canPractice in
                                Results(
                                    testTitle: test.title,
                                    endedAt: endedAt,
                                    testIsOpen: test.isOpen,
                                    executedAt: startedAt,
                                    shouldPresentDetails: test.isTeamBasedLearning == false,
                                    subjectID: subjectID,
                                    canPractice: canPractice,
                                    topicResults: tasks.group(by: \.1.id) // Grouping by topic id
                                        .compactMap { (id, topicTasks) in

                                            guard
                                                let topic = topicTasks.first?.1,
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
                                                        pivotID: task.0.0.id ?? 0,
                                                        question: task.0.1.question,
                                                        score: taskResults[task.0.1.id ?? 0] ?? 0
                                                    )
                                                }
                                            )
                                    }
                                )
                            }
                    }
            }
        }

        public func getSessions(for user: User) throws -> EventLoopFuture<[TestSession.HighOverview]> {

            conn.databaseConnection(to: .psql)
                .flatMap { conn in

                    return conn.select()
                        .column(\Subject.DatabaseModel.name, as: "subjectName")
                        .column(\Subject.DatabaseModel.id, as: "subjectID")
                        .column(\TestSession.DatabaseModel.id, as: "id")
                        .column(\TestSession.DatabaseModel.createdAt, as: "createdAt")
                        .column(\TestSession.DatabaseModel.submittedAt, as: "endedAt")
                        .column(\SubjectTest.DatabaseModel.title, as: "testTitle")
                        .from(TestSession.DatabaseModel.self)
                        .join(\TestSession.DatabaseModel.id, to: \TaskSession.id)
                        .join(\TestSession.DatabaseModel.testID, to: \SubjectTest.DatabaseModel.id)
                        .join(\SubjectTest.DatabaseModel.subjectID, to: \Subject.DatabaseModel.id)
                        .where(\TestSession.DatabaseModel.submittedAt != nil)
                        .where(\TaskSession.userID == user.id)
                        .all(decoding: TestSession.HighOverview.self)
            }
        }

        public func solutions(for user: User, in session: TestSessionRepresentable, pivotID: Int) throws -> EventLoopFuture<[TaskSolution.Response]> {

            guard
                session.hasSubmitted,
                user.id == session.userID
            else {
                throw Abort(.forbidden)
            }

            return SubjectTest.Pivot.Task
                .find(pivotID, on: conn)
                .unwrap(or: Abort(.badRequest))
                .flatMap { task in

                    guard task.testID == session.testID else { throw Abort(.badRequest) }

                    return self.taskSolutionRepository.solutions(for: task.taskID, for: user)
            }
        }

        public func results(in session: TestSessionRepresentable, pivotID: Int) throws -> EventLoopFuture<TestSession.DetailedTaskResult> {

            guard session.hasSubmitted else { throw Abort(.badRequest) }

            return self.subjectTestRepository
                .isOpen(testID: session.testID)
                .flatMap { isOpen in

                    guard isOpen == false else { throw TestSessionRepositoringError.testIsNotFinnished }

                    return SubjectTest.Pivot.Task.query(on: self.conn, withSoftDeleted: true)
                        .join(\Task.id, to: \SubjectTest.Pivot.Task.taskID)
                        .join(\MultipleChoiseTask.id, to: \Task.id)
                        .filter(\SubjectTest.Pivot.Task.id == pivotID)
                        .filter(\SubjectTest.Pivot.Task.testID == session.testID)
                        .alsoDecode(Task.self)
                        .alsoDecode(MultipleChoiseTask.self)
                        .first()
                        .unwrap(or: Abort(.badRequest))
                        .flatMap { (taskContent, multiple) in

                            let subjectTask = taskContent.0
                            let task = taskContent.1

                            guard subjectTask.testID == session.testID else { throw Abort(.badRequest) }

                            return self.multipleChoiseRepository
                                .choisesFor(taskID: subjectTask.taskID)
                                .flatMap { choises in

                                    try self.taskSessionAnswerRepository
                                        .multipleChoiseAnswers(in: session.requireID(), taskID: subjectTask.taskID)
                                        .map { selectedChoise in

                                            try TestSession.DetailedTaskResult(
                                                taskID: task.requireID(),
                                                description: task.description,
                                                question: task.question,
                                                isMultipleSelect: multiple.isMultipleSelect,
                                                testSessionID: session.requireID(),
                                                choises: choises,
                                                selectedChoises: selectedChoise.map { $0.choiseID }
                                            )
                                    }
                            }
                    }
            }
        }
    }
}
