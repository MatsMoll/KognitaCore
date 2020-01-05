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
            try print("-- Submitting to: \(session.requireID())")
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

                                    try print("-- Creating ansers for: \(session.requireID())")
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
                                try print("-- Aborting for: \(session.requireID())")
                                throw Abort(.badRequest)
                            }
                            try print("-- Updating for: \(session.requireID())")
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
            print("-- Saving to: \(sessionID)")
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

        struct Test: Codable {
            let count: Int
        }

        static func submit(test: TestSession, on conn: DatabaseConnectable) throws -> EventLoopFuture<Void> {
            guard test.submittedAt == nil else {
                throw Abort(.badRequest)
            }
            test.submittedAt = Date()

            return conn.databaseConnection(to: .psql)
                .flatMap { conn in

                    try conn.select()
                        .all(table: MultipleChoiseTaskChoise.self)
                        .column(.count(\MultipleChoiseTaskChoise.isCorrect), as: "count")
                        .from(TaskSessionAnswer.self)
                        .join(\TaskSessionAnswer.taskAnswerID,      to: \TaskAnswer.id)
                        .join(\TaskAnswer.id,                       to: \MultipleChoiseTaskAnswer.id)
                        .join(\MultipleChoiseTaskAnswer.choiseID,   to: \MultipleChoiseTaskChoise.id)
                        .where(\TaskSessionAnswer.sessionID == test.requireID())
                        .groupBy(\MultipleChoiseTaskChoise.id)
                        .all(decoding: MultipleChoiseTaskChoise.self, Test.self)
                        .map {
                            print($0)
                    }
            }
//            return try TaskSessionAnswer.query(on: conn)
//                .join(\TaskSessionAnswer.taskAnswerID,      to: \TaskAnswer.id)
//                .join(\TaskAnswer.id,                       to: \MultipleChoiseTaskAnswer.id)
//                .join(\MultipleChoiseTaskAnswer.choiseID,   to: \MultipleChoiseTaskChoise.id)
//                .filter(\TaskSessionAnswer.sessionID == test.requireID())
//                .filter(\MultipleChoiseTaskChoise.isCorrect == true)
//                .decode(MultipleChoiseTaskChoise.self)
//                .all()
//                .flatMap { (choises: [MultipleChoiseTaskChoise]) in
//                    return conn.future()
//            }
        }
    }
}
