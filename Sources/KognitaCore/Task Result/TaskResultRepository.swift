//
//  TaskResultRepository.swift
//  KognitaCore
//
//  Created by Mats Mollestad on 12/04/2019.
//

import FluentPostgreSQL
import FluentSQL
import Vapor

extension TaskResult {
    public class DatabaseRepository: TaskResultRepositoring {}
}

public protocol PracticeSessionRepresentable: Codable {
    var id: Int? { get }
    var userID: User.ID { get }
    var createdAt: Date? { get }
    var endedAt: Date? { get }
    var numberOfTaskGoal: Int { get }

    func requireID() throws -> Int

    func end(on conn: DatabaseConnectable) -> EventLoopFuture<PracticeSessionRepresentable>
    func extendSession(with numberOfTasks: Int, on conn: DatabaseConnectable) -> EventLoopFuture<PracticeSessionRepresentable>
}

extension TaskResult.DatabaseRepository {

    enum Errors: Error {
        case incompleateSqlStatment
    }

    public struct SpaceRepetitionTask: Codable {
        public let taskID: Task.ID
        public let revisitDate: Date
        public let createdAt: Date
        public let sessionID: TaskSession.ID?
    }

    private struct SubqueryResult: Codable {
        let id: Int
        let taskID: Int
    }

    private struct SubqueryTopicResult: Codable {
        let id: Int
        let taskID: Int
        let topicID: Int
    }

    private struct UserLevelScore: Codable {
        let resultScore: Double
        let topicID: Int
    }

    private enum Query {

        case subtopics
        case taskResults
        case flowTasks(userID: User.ID, sessionID: PracticeSession.ID)
        case results(revisitingAfter: Date, for: User.ID)
        case resultsInSubject(Subject.ID, for: User.ID)
        case resultsInTopics([Topic.ID], for: User.ID)

        var rawQuery: String {
            switch self {
            case .subtopics: return #"SELECT "PracticeSession_Subtopic"."subtopicID" FROM "PracticeSession_Subtopic" WHERE "PracticeSession_Subtopic"."sessionID" = ($2)"#
            case .taskResults: return #"SELECT DISTINCT ON ("taskID") * FROM "TaskResult" WHERE "TaskResult"."userID" = ($1) ORDER BY "taskID", "TaskResult"."createdAt" DESC"#
            case .flowTasks: return #"SELECT DISTINCT ON ("TaskResult"."taskID") "TaskResult"."taskID", "TaskResult"."createdAt" AS "createdAt", "TaskResult"."revisitDate", "TaskResult"."sessionID" FROM "TaskResult" INNER JOIN "Task" ON "TaskResult"."taskID" = "Task"."id" WHERE "Task"."deletedAt" IS NULL AND "TaskResult"."revisitDate" IS NOT NULL AND "TaskResult"."userID" = $1 AND "Task"."subtopicID" = ANY (SELECT "PracticeSession_Subtopic"."subtopicID" FROM "PracticeSession_Subtopic" WHERE "Task"."isTestable" = 'false' AND "PracticeSession_Subtopic"."sessionID" = ($2)) ORDER BY "TaskResult"."taskID" DESC, "TaskResult"."createdAt" DESC"#
            case .results:
                return #"SELECT DISTINCT ON ("taskID") "TaskResult"."id", "taskID" FROM "TaskResult" INNER JOIN "Task" ON "TaskResult"."taskID" = "Task"."id" WHERE "TaskResult"."userID" = ($1) AND "Task"."deletedAt" IS NULL AND "TaskResult"."revisitDate" > ($2) ORDER BY "taskID", "TaskResult"."createdAt" DESC"#
            case .resultsInTopics:
                return #"SELECT DISTINCT ON ("TaskResult"."taskID") "TaskResult"."id", "TaskResult"."taskID", "Topic"."id" AS "topicID" FROM "TaskResult" INNER JOIN "Task" ON "TaskResult"."taskID" = "Task"."id" INNER JOIN "Subtopic" ON "Task"."subtopicID" = "Subtopic"."id" INNER JOIN "Topic" ON "Subtopic"."topicId" = "Topic"."id" WHERE "Task"."deletedAt" IS NULL AND "userID" = ($1) AND "Topic"."id" = ANY($2) ORDER BY "TaskResult"."taskID", "TaskResult"."createdAt" DESC"#
            case .resultsInSubject:
                return #"SELECT DISTINCT ON ("TaskResult"."taskID") "TaskResult"."id", "TaskResult"."taskID" FROM "TaskResult" INNER JOIN "Task" ON "TaskResult"."taskID" = "Task"."id" INNER JOIN "Subtopic" ON "Task"."subtopicID" = "Subtopic"."id" INNER JOIN "Topic" ON "Subtopic"."topicId" = "Topic"."id" INNER JOIN "Subject" ON "Subject"."id" = "Topic"."subjectId" WHERE "Task"."deletedAt" IS NULL AND "userID" = ($1) AND "Subject"."id" = ($2) ORDER BY "TaskResult"."taskID", "TaskResult"."createdAt" DESC"#
            }
        }

        func query(for conn: PostgreSQLConnection) throws -> SQLRawBuilder<PostgreSQLConnection> {
            switch self {
            case .flowTasks(let userId, let sessionId):
                return conn.raw(self.rawQuery)
                    .bind(userId)
                    .bind(sessionId)
            case .results(revisitingAfter: let date, for: let userId):
                return conn.raw(self.rawQuery)
                    .bind(userId)
                    .bind(date)
            case .resultsInTopics(let topicIds, for: let userId):
                return conn.raw(self.rawQuery)
                    .bind(userId)
                    .bind(topicIds)
            case .resultsInSubject(let subjectId, for: let userId):
                return conn.raw(self.rawQuery)
                    .bind(userId)
                    .bind(subjectId)
            case .subtopics, .taskResults:
                throw Errors.incompleateSqlStatment
            }
        }
    }

    public static func getResults(on conn: DatabaseConnectable) -> EventLoopFuture<[UserResultOverview]> {

        conn.databaseConnection(to: .psql)
            .flatMap { psqlConn in

                psqlConn.select()
                    .column(.count(.all, as: "resultCount"))
                    .column(.keyPath(\User.DatabaseModel.id, as: "userID"))
                    .column(.keyPath(\User.DatabaseModel.username, as: "username"))
                    .column(.function("sum", [.expression(.column(\TaskResult.resultScore))]), as: "totalScore")
                    .from(User.DatabaseModel.self)
                    .join(\User.DatabaseModel.id, to: \TaskResult.userID)
                    .groupBy(\User.DatabaseModel.id)
                    .all(decoding: UserResultOverview.self)
        }
    }

    public static func getAllResults(for userId: User.ID, with conn: DatabaseConnectable) throws -> EventLoopFuture<[TaskResult]> {

        conn.databaseConnection(to: .psql)
            .flatMap { psqlConn in

                psqlConn.select()
                    .all(table: TaskResult.self)
                    .where(
                        .column(.keyPath(\TaskResult.id)),
                        .in,
                        .subquery(.raw(Query.taskResults.rawQuery, binds: [userId]))
                    )
                    .orderBy(\TaskResult.revisitDate)
                    .all(decoding: TaskResult.self)
        }
    }

    public static func getSpaceRepetitionTask(for session: PracticeSessionRepresentable, on conn: PostgreSQLConnection) throws -> EventLoopFuture<SpaceRepetitionTask?> {

        return try Query.flowTasks(
            userID: session.userID,
            sessionID: session.requireID()
        )
            .query(for: conn)
            .all(decoding: SpaceRepetitionTask.self)
            .map { tasks in
                let uncompletedTasks = try tasks.filter { try $0.sessionID != session.requireID() }
                let now = Date()
                let timeInADay: TimeInterval = 60 * 60 * 24

                return Dictionary(grouping: uncompletedTasks) { task in Int(now.timeIntervalSince(task.revisitDate) / timeInADay) }
                .filter { $0.key < 10 }
                .min { first, second in
                    first.key > second.key
                }?.value.random
        }
    }

    public static func getAllResults<A>(for userId: User.ID, filter: FilterOperator<PostgreSQLDatabase, A>, with conn: PostgreSQLConnection, maxRevisitDays: Int? = 10) throws -> EventLoopFuture<[TaskResult]> {

        let oneDayAgo = Date(timeIntervalSinceNow: -60*60*24*3)

        return try Query.results(
            revisitingAfter: oneDayAgo,
            for: userId
        )
            .query(for: conn)
            .all(decoding: SubqueryResult.self)
            .flatMap { result in

                let ids = result.map { $0.id }

                var query = TaskResult.query(on: conn)
                    .filter(\.id ~~ ids)
                    .filter(filter)
                    .sort(\.revisitDate)
                    .join(\Task.id, to: \TaskResult.taskID)
                    .join(\Subtopic.DatabaseModel.id, to: \Task.subtopicID)
                    .join(\Topic.DatabaseModel.id, to: \Subtopic.DatabaseModel.topicId)

                if let maxRevisitDays = maxRevisitDays,
                    let maxRevisitDaysDate = Calendar.current.date(byAdding: .day, value: maxRevisitDays, to: Date()) {
                    query = query
                        .filter(\TaskResult.revisitDate < maxRevisitDaysDate)
                }

                return query.all()
        }
    }

    public static func getAllResultsContent(for user: User, with conn: PostgreSQLConnection, limit: Int = 2) throws -> EventLoopFuture<[TopicResultContent]> {

        return try Query.results(
            revisitingAfter: Date(),
            for: user.id
        )
            .query(for: conn)
            .all(decoding: SubqueryResult.self)
            .flatMap { result in

                let ids = result.map { $0.id }
                return TaskResult.query(on: conn)
                    .filter(\.id ~~ ids)
                    .sort(\.revisitDate, .ascending)
                    .join(\Task.id, to: \TaskResult.taskID)
                    .join(\Subtopic.DatabaseModel.id, to: \Task.subtopicID)
                    .join(\Topic.DatabaseModel.id, to: \Subtopic.DatabaseModel.topicId)
                    .join(\Subject.DatabaseModel.id, to: \Topic.DatabaseModel.subjectId)
                    .alsoDecode(Topic.DatabaseModel.self)
                    .alsoDecode(Subject.DatabaseModel.self)
                    .range(...limit)
                    .all()
                    .map { contens in

                        var responses: [Topic.ID: TopicResultContent] = [:]

                        for content in contens {
                            let result = content.0.0
                            let topic = content.0.1

                            if let response = try responses[topic.requireID()] {
                                try responses[topic.requireID()] = TopicResultContent(results: response.results + [result], topic: topic.content(), subject: content.1.content())
                            } else {
                                try responses[topic.requireID()] = TopicResultContent(results: [result], topic: topic.content(), subject: content.1.content())
                            }
                        }
                        return responses.map { $0.value }
                            .sorted(by: { $0.revisitDate < $1.revisitDate })
                }
        }
    }

    public static func getAmountHistory(for user: User, on conn: PostgreSQLConnection, numberOfWeeks: Int = 4) throws -> EventLoopFuture<[TaskResult.History]> {

        let dateThreshold = Calendar.current.date(byAdding: .weekOfYear, value: -numberOfWeeks, to: Date()) ??
            Date().addingTimeInterval(-7 * 24 * 60 * 60 * Double(numberOfWeeks)) // Four weeks back

        return try conn.select()
            .column(.count(\TaskResult.id), as: "numberOfTasksCompleted")
            .column(.function("date_part", [.expression(.literal("year")), .expression(.column(.keyPath(\TaskResult.createdAt)))]), as: "year")
            .column(.function("date_part", [.expression(.literal("week")), .expression(.column(.keyPath(\TaskResult.createdAt)))]), as: "week")
            .from(TaskResult.self)
            .where(\TaskResult.userID == user.id)
            .where(\TaskResult.createdAt, .greaterThanOrEqual, dateThreshold)
            .groupBy(.column(.column(nil, "year")))
            .groupBy(.column(.column(nil, "week")))
            .all(decoding: TaskResult.History.self)
            .map { days in
                // FIXME: - there is a bug where the database uses one loale and the formatter another and this can leed to incorrect grouping
                let now = Date()

                var data = [String: TaskResult.History]()

                try (0...(numberOfWeeks - 1)).forEach {
                    let date = Calendar.current.date(byAdding: .weekOfYear, value: -$0, to: now) ??
                        now.addingTimeInterval(-TimeInterval($0) * 24 * 60 * 60 * 4)

                    let dateData = Calendar.current.dateComponents([.year, .weekOfYear], from: date)

                    guard
                        let year = dateData.year,
                        let week = dateData.weekOfYear
                    else {
                        throw Errors.incompleateSqlStatment
                    }

                    data["\(year)-\(week)"] = TaskResult.History(
                        numberOfTasksCompleted: 0,
                        year: Double(year),
                        week: Double(week)
                    )
                }

                for day in days {
                    data["\(Int(day.year))-\(Int(day.week))"] = day
                }

                return data.map { $1 }
                    .sorted(by: { first, second in
                        if first.year == second.year {
                            return first.week < second.week
                        } else {
                            return first.year < second.year
                        }
                })
        }
    }

    public static func getAmountHistory(for user: User, in subjectId: Subject.ID, on conn: PostgreSQLConnection, numberOfWeeks: Int = 4) throws -> EventLoopFuture<[TaskResult.History]> {

        let dateThreshold = Calendar.current.date(byAdding: .weekOfYear, value: -numberOfWeeks, to: Date()) ??
            Date().addingTimeInterval(-7 * 24 * 60 * 60 * Double(numberOfWeeks)) // Four weeks back

        return try conn.select()
            .column(.count(\TaskResult.id), as: "numberOfTasksCompleted")
            .column(.function("date_part", [.expression(.literal("year")), .expression(.column(.keyPath(\TaskResult.createdAt)))]), as: "year")
            .column(.function("date_part", [.expression(.literal("week")), .expression(.column(.keyPath(\TaskResult.createdAt)))]), as: "week")
            .from(TaskResult.self)
            .join(\TaskResult.taskID, to: \Task.id)
            .join(\Task.subtopicID, to: \Subtopic.DatabaseModel.id)
            .join(\Subtopic.DatabaseModel.topicId, to: \Topic.DatabaseModel.id)
            .where(\TaskResult.userID == user.id)
            .where(\TaskResult.createdAt, .greaterThanOrEqual, dateThreshold)
            .where(\Topic.DatabaseModel.subjectId == subjectId)
            .groupBy(.column(.column(nil, "year")))
            .groupBy(.column(.column(nil, "week")))
            .all(decoding: TaskResult.History.self)
            .map { days in
                // FIXME: - there is a bug where the database uses one loale and the formatter another and this can leed to incorrect grouping
                let now = Date()

                var data = [String: TaskResult.History]()

                try (0...(numberOfWeeks - 1)).forEach {
                    let date = Calendar.current.date(byAdding: .weekOfYear, value: -$0, to: now) ??
                        now.addingTimeInterval(-TimeInterval($0) * 24 * 60 * 60 * 4)

                    let dateData = Calendar.current.dateComponents([.year, .weekOfYear], from: date)

                    guard
                        let year = dateData.year,
                        let week = dateData.weekOfYear
                    else {
                        throw Errors.incompleateSqlStatment
                    }

                    data["\(year)-\(week)"] = TaskResult.History(
                        numberOfTasksCompleted: 0,
                        year: Double(year),
                        week: Double(week)
                    )
                }

                for day in days {
                    data["\(Int(day.year))-\(Int(day.week))"] = day
                }

                return data.map { $1 }
                    .sorted(by: { first, second in
                        if first.year == second.year {
                            return first.week < second.week
                        } else {
                            return first.year < second.year
                        }
                })
        }
    }

    static func createResult(from result: TaskSubmitResultRepresentable, userID: User.ID, with sessionID: TaskSession.ID, on conn: DatabaseConnectable) -> EventLoopFuture<TaskResult> {
        return TaskResult(result: result, userID: userID, sessionID: sessionID)
            .save(on: conn)
    }

    public static func getUserLevel(for userId: User.ID, in topics: [Topic.ID], on conn: DatabaseConnectable) throws -> EventLoopFuture<[User.TopicLevel]> {

        return conn.databaseConnection(to: .psql)
            .flatMap { psqlConn in

                try Query.resultsInTopics(topics, for: userId)
                    .query(for: psqlConn)
                    .all(decoding: SubqueryTopicResult.self)
                    .flatMap { result in

                        let ids = result.map { $0.id }

                        return psqlConn.select()
                            .column(.column(\TaskResult.resultScore), as: "resultScore")
                            .column(.column(\Topic.DatabaseModel.id), as: "topicID")
                            .from(TaskResult.self)
                            .where(\TaskResult.id, .in, ids)
                            .join(\TaskResult.taskID, to: \Task.id)
                            .join(\Task.subtopicID, to: \Subtopic.DatabaseModel.id)
                            .join(\Subtopic.DatabaseModel.topicId, to: \Topic.DatabaseModel.id)
                            .all(decoding: UserLevelScore.self)
                            .flatMap { scores in

                                return scores.group(by: \UserLevelScore.topicID)
                                    .map { topicID, grouped in

                                    Task.query(on: psqlConn)
                                        .join(\Subtopic.DatabaseModel.id, to: \Task.subtopicID)
                                        .filter(\Subtopic.DatabaseModel.topicId == topicID)
                                        .count()
                                        .map { maxScore in
                                            User.TopicLevel(
                                                topicID: topicID,
                                                correctScore: grouped.reduce(0) { $0 + $1.resultScore.clamped(to: 0...1) },
                                                maxScore: Double(maxScore)
                                            )
                                    }
                                }.flatten(on: conn)
                        }
                }
        }
    }

    public static func getUserLevel(in subject: Subject, userId: User.ID, on conn: DatabaseConnectable) throws -> EventLoopFuture<User.SubjectLevel> {

        conn.databaseConnection(to: .psql)
            .flatMap { psqlConn in

                try Query.resultsInSubject(subject.id, for: userId)
                    .query(for: psqlConn)
                    .all(decoding: SubqueryResult.self)
                    .flatMap { result in

                        let ids = result.map { $0.id }

                        guard ids.isEmpty == false else {
                            return psqlConn.future(
                                User.SubjectLevel(subjectID: subject.id, correctScore: 0, maxScore: 1)
                            )
                        }

                        return TaskResult.query(on: psqlConn)
                            .filter(\.id ~~ ids)
                            .sum(\.resultScore)
                            .flatMap { score in

                                Task.query(on: psqlConn)
                                    .join(\Subtopic.DatabaseModel.id, to: \Task.subtopicID)
                                    .join(\Topic.DatabaseModel.id, to: \Subtopic.DatabaseModel.topicId)
                                    .filter(\Topic.DatabaseModel.subjectId == subject.id)
                                    .count()
                                    .map { maxScore in

                                        User.SubjectLevel(
                                            subjectID: subject.id,
                                            correctScore: score,
                                            maxScore: Double(maxScore)
                                        )
                                }
                        }
                }
        }
    }

    public static func getLastResult(for taskID: Task.ID, by userId: User.ID, on conn: DatabaseConnectable) throws -> EventLoopFuture<TaskResult?> {
        return TaskResult.query(on: conn)
            .filter(\TaskResult.taskID == taskID)
            .filter(\TaskResult.userID == userId)
            .sort(\.createdAt, .descending)
            .first()
    }

    public static func exportResults(on conn: DatabaseConnectable) throws -> EventLoopFuture<[TaskResult.Answer]> {

        let query = #"SELECT "TaskResult".*, "FlashCardAnswer".*, "MultipleChoiseTaskAnswer".* FROM "TaskResult" FULL OUTER JOIN "FlashCardAnswer" ON "FlashCardAnswer"."taskID" = "TaskResult"."taskID" AND "FlashCardAnswer"."sessionID" = "TaskResult"."sessionID" LEFT JOIN "MultipleChoiseTaskChoise" ON "TaskResult"."taskID" = "MultipleChoiseTaskChoise"."taskId" FULL OUTER JOIN "MultipleChoiseTaskAnswer" ON "MultipleChoiseTaskAnswer"."choiseID" = "MultipleChoiseTaskChoise"."id" AND "MultipleChoiseTaskChoise"."taskId" = "TaskResult"."taskID" AND "MultipleChoiseTaskAnswer"."sessionID" = "TaskResult"."sessionID" ORDER BY "createdAt" DESC;"#

        return conn.databaseConnection(to: .psql)
            .flatMap { psqlConn in

                psqlConn.raw(query)
                    .all(decoding: TaskResult.self, MultipleChoiseTaskAnswer?.self, FlashCardAnswer?.self)
                    .map { results in
                        results
                            .map { (result, multiple, flash) in
                                TaskResult.Answer(
                                    result: result,
                                    multiple: multiple,
                                    flash: flash
                                )
                        }
                }
                .map(Set.init)
                .map(Array.init)
        }
    }
}

public protocol TaskSubmitResultRepresentable: TaskSubmitResultable, TaskSubmitable {
    var taskID: Task.ID { get }
}

struct TaskSubmitResult: TaskSubmitResultRepresentable {
    public let submit: TaskSubmitable
    public let result: TaskSubmitResultable
    public let taskID: Task.ID

    var timeUsed: TimeInterval? { submit.timeUsed }
    var score: Double { result.score }
}

extension User {
    public struct TopicLevel: Codable {
        public let topicID: Topic.ID
        public let correctScore: Double
        public let maxScore: Double

        public var correctScoreInteger: Int { return Int(correctScore.rounded()) }
        public var correctProsentage: Double {
            return (correctScore * 1000 / maxScore).rounded() / 10
        }
    }

    public struct SubjectLevel: Codable {
        public let subjectID: Subject.ID
        public let correctScore: Double
        public let maxScore: Double

        public var correctScoreInteger: Int { return Int(correctScore.rounded()) }
        public var correctProsentage: Double {
            guard maxScore.isNormal else {
                return 0
            }
            return (correctScore * 1000 / maxScore).rounded() / 10
        }
    }
}

extension TaskResult {
    public struct Answer: Codable, Hashable {

        public static func == (lhs: Answer, rhs: Answer) -> Bool {
            lhs.result.id == rhs.result.id && lhs.multiple?.choiseID == rhs.multiple?.choiseID
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(result.id)
            hasher.combine(multiple?.choiseID)
        }

        let result: TaskResult
        let multiple: MultipleChoiseTaskAnswer?
        let flash: FlashCardAnswer?
    }
}
