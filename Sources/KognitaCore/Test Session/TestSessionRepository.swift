import Vapor
import FluentSQL
import FluentPostgreSQL

extension TestSession {
    public class DatabaseRepository {

        public static func submit(content: FlashCardTask.Submit, for session: TestSession, by user: User, on conn: DatabaseConnectable) throws -> EventLoopFuture<Void> {
            guard user.id == session.userID else {
                throw Abort(.forbidden)
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

                                            try save(answer: answer, to: session, on: conn)
                                    }
                            }
                    }
            }
        }

        static func update(answer content: FlashCardTask.Submit, for session: TestSession, by user: User, on conn: DatabaseConnectable) -> EventLoopFuture<Void> {
            return conn.databaseConnection(to: .psql)
                .flatMap { psqlConn in

                    return try psqlConn.select()
                        .all(table: FlashCardAnswer.self)
                        .from(SubjectTest.Pivot.Task.self)
                        .join(\SubjectTest.Pivot.Task.taskID,   to: \SubjectTest.id)
                        .join(\SubjectTest.id,                  to: \TestSession.testID)
                        .join(\TestSession.id,                  to: \SubjectTestAnswer.testID,  method: .left)
                        .join(\SubjectTestAnswer.taskAnswerID,  to: \FlashCardAnswer.id,        method: .left)
                        .where(\TestSession.userID == user.requireID())
                        .orderBy(\SubjectTest.Pivot.Task.createdAt, .ascending)
                        .offset(content.taskIndex - 1)
                        .limit(1)
                        .first(decoding: FlashCardAnswer?.self)
                        .unwrap(or: Abort(.badRequest))
                        .flatMap { answer in
                            answer.answer = content.answer
                            return answer.save(on: conn)
                                .transform(to: ())
                    }
            }
        }

        static func save(answer: TaskAnswer, to test: TestSession, on conn: DatabaseConnectable) throws -> EventLoopFuture<Void> {
            try SubjectTestAnswer(
                testID: test.requireID(),
                taskAnswerID: answer.requireID()
            )
            .create(on: conn)
            .transform(to: ())
        }

        static func flashCard(at index: Int, on conn: DatabaseConnectable) -> EventLoopFuture<FlashCardTask> {
            SubjectTest.Pivot.Task.query(on: conn)
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
    }
}
