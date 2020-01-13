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
}

extension TaskResult.DatabaseRepository {

    enum Errors: Error {
        case incompleateSqlStatment
    }

    public struct FlowZoneTaskResult: Codable {
        public let taskID: Task.ID
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
        case flowTasks(for: User.ID, in: PracticeSession.ID, under: Double)
        case results(revisitingAfter: Date, for: User.ID)
        case resultsInSubject(Subject.ID, for: User.ID)
        case resultsInTopics([Topic.ID], for: User.ID)

        var rawQuery: String {
            switch self {
            case .subtopics: return #"SELECT "PracticeSession_Subtopic"."subtopicID" FROM "PracticeSession_Subtopic" WHERE "PracticeSession_Subtopic"."sessionID" = ($2)"#
            case .taskResults: return #"SELECT DISTINCT ON ("taskID") * FROM "TaskResult" WHERE "TaskResult"."userID" = ($1) ORDER BY "taskID", "TaskResult"."createdAt" DESC"#
            case .flowTasks: return "SELECT * FROM (\(Query.taskResults.rawQuery)) AS \"Result\" INNER JOIN \"Task\" ON \"Task\".\"id\" = \"Result\".\"taskID\" WHERE \"Result\".\"sessionID\" != ($2) AND \"Task\".\"deletedAt\" IS NULL AND \"Result\".\"resultScore\" <= ($3) AND \"Task\".\"subtopicID\" = ANY (\(Query.subtopics.rawQuery)) ORDER BY \"Result\".\"resultScore\" DESC, \"Result\".\"createdAt\" DESC"
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
            case .flowTasks(let userId, let sessionId, let scoreThreshold):
                return conn.raw(self.rawQuery)
                    .bind(userId)
                    .bind(sessionId)
                    .bind(scoreThreshold)
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
                    .column(.keyPath(\User.id, as: "userID"))
                    .column(.keyPath(\User.username, as: "username"))
                    .column(.function("sum", [.expression(.column(\TaskResult.resultScore))]), as: "totalScore")
                    .from(User.self)
                    .join(\User.id, to: \TaskResult.userID)
                    .groupBy(\User.id)
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

    public static func getFlowZoneTasks(for session: PracticeSessionRepresentable, on conn: PostgreSQLConnection) throws -> EventLoopFuture<FlowZoneTaskResult?> {

//        let oneDayAgo = Date(timeIntervalSinceNow: -60*60*24*3)
        let scoreThreshold: Double = 0.8

        return try Query.flowTasks(
            for: session.userID,
            in: session.requireID(),
            under: scoreThreshold
        )
            .query(for: conn)
            .first(decoding: FlowZoneTaskResult.self)
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
                    .join(\Subtopic.id, to: \Task.subtopicID)
                    .join(\Topic.id, to: \Subtopic.topicId)

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
            for: user.requireID()
        )
            .query(for: conn)
            .all(decoding: SubqueryResult.self)
            .flatMap { result in

                let ids = result.map { $0.id }
                return TaskResult.query(on: conn)
                    .filter(\.id ~~ ids)
                    .sort(\.revisitDate, .ascending)
                    .join(\Task.id,     to: \TaskResult.taskID)
                    .join(\Subtopic.id, to: \Task.subtopicID)
                    .join(\Topic.id,    to: \Subtopic.topicId)
                    .join(\Subject.id,  to: \Topic.subjectId)
                    .alsoDecode(Topic.self)
                    .alsoDecode(Subject.self)
                    .range(...limit)
                    .all()
                    .map { contens in

                        var responses: [Topic.ID: TopicResultContent] = [:]

                        for content in contens {
                            let result = content.0.0
                            let topic = content.0.1

                            if let response = try responses[topic.requireID()] {
                                try responses[topic.requireID()] = TopicResultContent(results: response.results + [result], topic: topic, subject: content.1)
                            } else {
                                try responses[topic.requireID()] = TopicResultContent(results: [result], topic: topic, subject: content.1)
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
            .where(\TaskResult.userID == user.requireID())
            .where(\TaskResult.createdAt, .greaterThanOrEqual, dateThreshold)
            .groupBy(.column(.column(nil, "year")))
            .groupBy(.column(.column(nil, "week")))
            .all(decoding: TaskResult.History.self)
            .map { days in
                // FIXME: - there is a bug where the database uses one loale and the formatter another and this can leed to incorrect grouping
                let now = Date()

                var data = [String : TaskResult.History]()

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
            .join(\Task.subtopicID, to: \Subtopic.id)
            .join(\Subtopic.topicId, to: \Topic.id)
            .where(\TaskResult.userID == user.requireID())
            .where(\TaskResult.createdAt, .greaterThanOrEqual, dateThreshold)
            .where(\Topic.subjectId == subjectId)
            .groupBy(.column(.column(nil, "year")))
            .groupBy(.column(.column(nil, "week")))
            .all(decoding: TaskResult.History.self)
            .map { days in
                // FIXME: - there is a bug where the database uses one loale and the formatter another and this can leed to incorrect grouping
                let now = Date()

                var data = [String : TaskResult.History]()

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

    static func createResult(from result: TaskSubmitResultRepresentable, by user: User, with sessionID: TaskSession.ID, on conn: DatabaseConnectable) throws -> EventLoopFuture<TaskResult> {
        return try TaskResult(result: result, userID: user.requireID(), sessionID: sessionID)
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
                            .column(.column(\Topic.id), as: "topicID")
                            .from(TaskResult.self)
                            .where(\TaskResult.id, .in, ids)
                            .join(\TaskResult.taskID, to: \Task.id)
                            .join(\Task.subtopicID, to: \Subtopic.id)
                            .join(\Subtopic.topicId, to: \Topic.id)
                            .all(decoding: UserLevelScore.self)
                            .flatMap { scores in

                                return scores.group(by: \UserLevelScore.topicID)
                                    .map { topicID, grouped in

                                    Task.query(on: psqlConn)
                                        .join(\Subtopic.id, to: \Task.subtopicID)
                                        .filter(\Subtopic.topicId == topicID)
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

                try Query.resultsInSubject(subject.requireID(), for: userId)
                    .query(for: psqlConn)
                    .all(decoding: SubqueryResult.self)
                    .flatMap { result in

                        let ids = result.map { $0.id }

                        guard ids.isEmpty == false else {
                            return psqlConn.future(
                                try User.SubjectLevel(subjectID: subject.requireID(), correctScore: 0, maxScore: 1)
                            )
                        }

                        return TaskResult.query(on: psqlConn)
                            .filter(\.id ~~ ids)
                            .sum(\.resultScore)
                            .flatMap { score in

                                try Task.query(on: psqlConn)
                                    .join(\Subtopic.id, to: \Task.subtopicID)
                                    .join(\Topic.id, to: \Subtopic.topicId)
                                    .filter(\Topic.subjectId == subject.requireID())
                                    .count()
                                    .map { maxScore in

                                        try User.SubjectLevel(
                                            subjectID: subject.requireID(),
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

    var timeUsed: TimeInterval?     { submit.timeUsed }
    var score: Double               { result.score }
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
            return (correctScore * 1000 / maxScore).rounded() / 10
        }
    }
}

extension Subject {
    public struct Details: Codable {
        public let subject: Subject
        public let topics: [Topic.WithTaskCount]
        public let levels: [User.TopicLevel]
        public let subjectLevel: User.SubjectLevel

        public init(subject: Subject, topics: [Topic.WithTaskCount], levels: [User.TopicLevel]) {
            self.subject = subject
            self.topics = topics
            self.levels = levels

            var correctScore: Double = 0
            var maxScore: Double = 0

            for level in levels {
                correctScore += level.correctScore
                maxScore += level.maxScore
            }

            self.subjectLevel = User.SubjectLevel(
                subjectID: subject.id ?? 0,
                correctScore: correctScore,
                maxScore: maxScore
            )
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
