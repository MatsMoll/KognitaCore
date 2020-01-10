import Vapor
import FluentSQL
import FluentPostgreSQL

public protocol TestSessionRepresentable {
    var userID: User.ID { get }
    var testID: SubjectTest.ID { get }
    var submittedAt: Date? { get }

    func requireID() throws -> Int
}


extension TestSession {
    public class DatabaseRepository {

        public static func submit(content: FlashCardTask.Submit, for session: TestSessionRepresentable, by user: User, on conn: DatabaseConnectable) throws -> EventLoopFuture<Void> {
            guard user.id == session.userID else {
                throw Abort(.forbidden)
            }
            guard session.submittedAt == nil else {
                throw Abort(.badRequest)
            }
            return SubjectTest.find(session.testID, on: conn)
                .unwrap(or: Abort(.badRequest))
                .flatMap { test in
                    guard test.isOpen else {
                        throw SubjectTest.DatabaseRepository.Errors.testIsClosed
                    }
                    return update(answer: content, for: session, by: user, on: conn)
                        .catchFlatMap { _ in

                            flashCard(at: content.taskIndex, on: conn)
                                .flatMap { task in

                                    FlashCardTask.DatabaseRepository
                                        .createAnswer(for: task, with: content, on: conn)
                                        .flatMap { answer in

                                            try save(answer: answer, to: session.requireID(), on: conn)
                                    }
                            }
                    }
            }
        }

        public static func submit(content: MultipleChoiseTask.Submit, for session: TestSessionRepresentable, by user: User, on conn: DatabaseConnectable) throws -> EventLoopFuture<Void> {
            guard user.id == session.userID else {
                throw Abort(.forbidden)
            }
            guard session.submittedAt == nil else {
                throw Abort(.badRequest)
            }
            return SubjectTest.find(session.testID, on: conn)
                .unwrap(or: Abort(.badRequest))
                .flatMap { test in
                    guard test.isOpen else {
                        throw SubjectTest.DatabaseRepository.Errors.testIsClosed
                    }
                    return choisesAt(index: content.taskIndex, on: conn)
                        .flatMap { choises in
                            guard choises.isEmpty == false else {
                                throw Abort(.badRequest)
                            }
                            let choisesIDs = Set(choises.map { $0.id })
                            guard content.choises.filter({ choisesIDs.contains($0) }).isEmpty == false else {
                                throw Abort(.badRequest)
                            }
                            return update(answer: content, for: session, by: user, on: conn)
                                .catchFlatMap { _ in

                                    return MultipleChoiseTask.DatabaseRepository
                                        .create(answer: content, on: conn)
                                        .flatMap { answers in

                                            try answers.map { answer in
                                                try save(answer: answer, to: session.requireID(), on: conn)
                                            }
                                            .flatten(on: conn)
                                    }
                            }
                    }
            }
        }

        static func update(answer content: MultipleChoiseTask.Submit, for session: TestSessionRepresentable, by user: User, on conn: DatabaseConnectable) -> EventLoopFuture<Void> {
            return conn.databaseConnection(to: .psql)
                .flatMap { psqlConn in

                    return try psqlConn.select()
                        .all(table: MultipleChoiseTaskAnswer.self)
                        .all(table: TaskAnswer.self)
                        .from(TestSession.self)
                        .join(\TestSession.id,                      to: \TaskSessionAnswer.sessionID)
                        .join(\TaskSessionAnswer.taskAnswerID,      to: \TaskAnswer.id)
                        .join(\TaskAnswer.id,                       to: \MultipleChoiseTaskAnswer.id)
                        .join(\MultipleChoiseTaskAnswer.choiseID,   to: \MultipleChoiseTaskChoise.id)
                        .join(\MultipleChoiseTaskChoise.taskId,     to: \SubjectTest.Pivot.Task.taskID)
                        .where(\TestSession.id == session.requireID())
                        .where(\SubjectTest.Pivot.Task.id == content.taskIndex)
                        .all(decoding: MultipleChoiseTaskAnswer.self, TaskAnswer.self)
                        .flatMap { answers in
                            guard answers.isEmpty == false else {
                                throw Abort(.badRequest)
                            }
                            let choisesIDs = answers.map { $0.0.choiseID }
                            return content.choises
                                .changes(from: choisesIDs)
                                .compactMap { change in
                                    switch change {
                                    case .insert(let choiseID):
                                        return MultipleChoiseTask.DatabaseRepository
                                            .createAnswer(choiseID: choiseID, on: conn)
                                            .flatMap { answer in
                                                try save(answer: answer, to: session.requireID(), on: conn)
                                        }
                                    case .remove(let choiseID):
                                        return answers.first(where: { $0.0.choiseID == choiseID })?.1
                                            .delete(on: conn)
                                    }
                            }
                            .flatten(on: conn)
                    }
            }
        }

        static func update(answer content: FlashCardTask.Submit, for session: TestSessionRepresentable, by user: User, on conn: DatabaseConnectable) -> EventLoopFuture<Void> {
            return conn.databaseConnection(to: .psql)
                .flatMap { psqlConn in

                    return try psqlConn.select()
                        .all(table: FlashCardAnswer.self)
                        .from(SubjectTest.Pivot.Task.self)
                        .join(\SubjectTest.Pivot.Task.taskID,   to: \SubjectTest.id)
                        .join(\SubjectTest.id,                  to: \TestSession.testID)
                        .join(\TestSession.id,                  to: \TaskSession.id)
                        .join(\TestSession.id,                  to: \TaskSessionAnswer.sessionID,   method: .left)
                        .join(\TaskSessionAnswer.taskAnswerID,  to: \FlashCardAnswer.id,            method: .left)
                        .where(\TaskSession.userID == user.requireID())
                        .orderBy(\SubjectTest.Pivot.Task.createdAt, .ascending)
                        .where(\SubjectTest.Pivot.Task.id == content.taskIndex)
                        .first(decoding: FlashCardAnswer?.self)
                        .unwrap(or: Abort(.badRequest))
                        .flatMap { answer in
                            answer.answer = content.answer
                            return answer.save(on: conn)
                                .transform(to: ())
                    }
            }
        }

        static func save(answer: TaskAnswer, to sessionID: TestSession.ID, on conn: DatabaseConnectable) throws -> EventLoopFuture<Void> {
            return try TaskSessionAnswer(
                sessionID: sessionID,
                taskAnswerID: answer.requireID()
            )
            .create(on: conn)
            .transform(to: ())
        }

        static func flashCard(at index: Int, on conn: DatabaseConnectable) -> EventLoopFuture<FlashCardTask> {
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

        static func choisesAt(index: Int, on conn: DatabaseConnectable) -> EventLoopFuture<[MultipleChoiseTaskChoise]> {
            SubjectTest.Pivot.Task.query(on: conn)
                .filter(\.id == index)
                .join(\MultipleChoiseTaskChoise.taskId, to: \SubjectTest.Pivot.Task.taskID)
                .decode(MultipleChoiseTaskChoise.self)
                .all()
        }

        static func submit(test: TestSession, by user: User, on conn: DatabaseConnectable) throws -> EventLoopFuture<Void> {
            guard test.submittedAt == nil else {
                throw Abort(.badRequest)
            }

            test.submittedAt = Date()

            return test.save(on: conn)
                .flatMap { _ in
                    conn.databaseConnection(to: .psql)
                        .flatMap { psqlConn in

                            try psqlConn.select()
                                .all(table: MultipleChoiseTaskChoise.self)
                                .from(TaskSessionAnswer.self)
                                .join(\TaskSessionAnswer.taskAnswerID,      to: \TaskAnswer.id)
                                .join(\TaskAnswer.id,                       to: \MultipleChoiseTaskAnswer.id)
                                .join(\MultipleChoiseTaskAnswer.choiseID,   to: \MultipleChoiseTaskChoise.id)
                                .where(\TaskSessionAnswer.sessionID == test.requireID())
                                .all(decoding: MultipleChoiseTaskChoise.self)
                                .flatMap { choises in
                                    choises.group(by: \.taskId)
                                        .map { taskID, choises in

                                            MultipleChoiseTask.DatabaseRepository
                                                .correctChoisesFor(taskID: taskID, on: psqlConn)
                                                .map { correctChoises in

                                                    try MultipleChoiseTask.DatabaseRepository
                                                        .evaluate(choises.map { try $0.requireID() }, agenst: correctChoises)
                                                        .representableWith(taskID: taskID)
                                            }
                                    }
                                    .flatten(on: psqlConn)
                            }
                            .flatMap { results in
                                try results.map { result in
                                    try TaskResult.DatabaseRepository
                                        .createResult(from: result, by: user, with: test.requireID(), on: psqlConn)
                                }
                                .flatten(on: psqlConn)
                            }
                            .transform(to: ())
                    }
            }
        }


        public static func results(in test: SubjectTest, for user: User, on conn: DatabaseConnectable) throws -> EventLoopFuture<Results> {

            return try TestSession.query(on: conn)
                .join(\TaskSession.id, to: \TestSession.id)
                .join(\SubjectTest.id, to: \TestSession.testID)
                .join(\TaskResult.sessionID, to: \TestSession.id)
                .filter(\TaskSession.userID == user.requireID())
                .filter(\TestSession.testID == test.requireID())
                .decode(SubjectTest.self)
                .alsoDecode(TaskResult.self)
                .all()
                .flatMap { results in

                    guard let test = results.first?.0 else {
                        throw Abort(.internalServerError)
                    }

                    return try SubjectTest.Pivot.Task.query(on: conn)
                        .join(\Task.id, to: \SubjectTest.Pivot.Task.taskID)
                        .join(\Subtopic.id, to: \Task.subtopicID)
                        .join(\Topic.id, to: \Subtopic.topicId)
                        .filter(\.testID == test.requireID())
                        .decode(Task.self)
                        .alsoDecode(Topic.self)
                        .all()
                        .map { tasks in

                            // Registrating the score for a given task
                            let taskResults = results.reduce(
                                into: [Task.ID : Double]()
                            ) { taskResults, result in
                                taskResults[result.1.taskID] = result.1.resultScore
                            }

                            return Results(
                                testTitle: test.title,
                                executedAt: test.scheduledAt, // FIXME: - Set a correct executedAt date
                                shouldPresentDetails: false,
                                topicResults: tasks.group(by: \.1.id) // Grouping by topic id
                                    .compactMap { (_, topicTasks) in

                                        guard let topic = topicTasks.first?.1 else {
                                            return nil
                                        }

                                        return Results.Topic(
                                            name: topic.name,
                                            taskResults: topicTasks.map { task in
                                                // Calculating the score for a given task and defaulting to 0 in score
                                                Results.Task(
                                                    question: task.0.question,
                                                    score: taskResults[task.0.id ?? 0] ?? 0
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
