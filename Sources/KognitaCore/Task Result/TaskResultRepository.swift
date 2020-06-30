//
//  TaskResultRepository.swift
//  KognitaCore
//
//  Created by Mats Mollestad on 12/04/2019.
//
import FluentKit
import FluentPostgresDriver
import Vapor

extension TaskResult {
    public class DatabaseRepository: TaskResultRepositoring {
        public init() {}
    }
}

public protocol PracticeSessionRepresentable: Codable {
    var id: Int? { get }
    var userID: User.ID { get }
    var createdAt: Date? { get }
    var endedAt: Date? { get }
    var numberOfTaskGoal: Int { get }

    func requireID() throws -> Int

    func content() -> PracticeSession

    func end(on database: Database) -> EventLoopFuture<PracticeSessionRepresentable>
    func extendSession(with numberOfTasks: Int, on database: Database) -> EventLoopFuture<PracticeSessionRepresentable>
}

public struct SpaceRepetitionTask: Codable {
    let taskID: Task.ID
    let revisitDate: Date
    let createdAt: Date
    let sessionID: TaskSession.IDValue?
}

extension TaskResult.DatabaseRepository {

    enum Errors: Error {
        case incompleateSqlStatment
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

        var rawQuery: SQLQueryString {
            switch self {
            case .subtopics: return #"SELECT "PracticeSession_Subtopic"."subtopicID" FROM "PracticeSession_Subtopic" WHERE "PracticeSession_Subtopic"."sessionID" = ($2)"#
            case .taskResults: return #"SELECT DISTINCT ON ("taskID") * FROM "TaskResult" WHERE "TaskResult"."userID" = ($1) ORDER BY "taskID", "TaskResult"."createdAt" DESC"#
            case .flowTasks(let userID, let sessionID): return #"SELECT DISTINCT ON ("TaskResult"."taskID") "TaskResult"."taskID", "TaskResult"."createdAt" AS "createdAt", "TaskResult"."revisitDate", "TaskResult"."sessionID" FROM "TaskResult" INNER JOIN "Task" ON "TaskResult"."taskID" = "Task"."id" WHERE "Task"."deletedAt" IS NULL AND "TaskResult"."revisitDate" IS NOT NULL AND "TaskResult"."userID" = \#(bind: userID) AND "Task"."subtopicID" = ANY (SELECT "PracticeSession_Subtopic"."subtopicID" FROM "PracticeSession_Subtopic" WHERE "Task"."isTestable" = 'false' AND "PracticeSession_Subtopic"."sessionID" = \#(bind: sessionID)) ORDER BY "TaskResult"."taskID" DESC, "TaskResult"."createdAt" DESC"#
            case .results:
                return #"SELECT DISTINCT ON ("taskID") "TaskResult"."id", "taskID" FROM "TaskResult" INNER JOIN "Task" ON "TaskResult"."taskID" = "Task"."id" WHERE "TaskResult"."userID" = ($1) AND "Task"."deletedAt" IS NULL AND "TaskResult"."revisitDate" > ($2) ORDER BY "taskID", "TaskResult"."createdAt" DESC"#
            case .resultsInTopics(let topicIDs, let userID):
                return #"SELECT DISTINCT ON ("TaskResult"."taskID") "TaskResult"."id", "TaskResult"."taskID", "Topic"."id" AS "topicID" FROM "TaskResult" INNER JOIN "Task" ON "TaskResult"."taskID" = "Task"."id" INNER JOIN "Subtopic" ON "Task"."subtopicID" = "Subtopic"."id" INNER JOIN "Topic" ON "Subtopic"."topicID" = "Topic"."id" WHERE "Task"."deletedAt" IS NULL AND "userID" = \#(bind: userID) AND "Topic"."id" = ANY(\#(bind: topicIDs)) ORDER BY "TaskResult"."taskID", "TaskResult"."createdAt" DESC"#
            case .resultsInSubject(let subjectID, let userID):
                return #"SELECT DISTINCT ON ("TaskResult"."taskID") "TaskResult"."id", "TaskResult"."taskID" FROM "TaskResult" INNER JOIN "Task" ON "TaskResult"."taskID" = "Task"."id" INNER JOIN "Subtopic" ON "Task"."subtopicID" = "Subtopic"."id" INNER JOIN "Topic" ON "Subtopic"."topicID" = "Topic"."id" INNER JOIN "Subject" ON "Subject"."id" = "Topic"."subjectId" WHERE "Task"."deletedAt" IS NULL AND "userID" = \#(bind: userID) AND "Subject"."id" = \#(bind: subjectID) ORDER BY "TaskResult"."taskID", "TaskResult"."createdAt" DESC"#
            }
        }

        func query(for database: Database) throws -> SQLRawBuilder {

            guard let sqlDB = database as? SQLDatabase else {
                throw Abort(.internalServerError)
            }
            switch self {
            case .resultsInSubject, .flowTasks, .results, .resultsInTopics:
                return sqlDB.raw(self.rawQuery)
            case .subtopics, .taskResults:
                throw Errors.incompleateSqlStatment
            }
        }
    }

    public static func getResults(on database: Database) -> EventLoopFuture<[UserResultOverview]> {

        guard let sqlDB = database as? SQLDatabase else {
            return database.eventLoop.future(error: Abort(.internalServerError))
        }
        return database.eventLoop.future(error: Abort(.notImplemented))
//        sqlDB.select()
//            .columns(SQLFunction("count", args: SQLLiteral.all))
//            .column(.count(.all, as: "resultCount"))
//            .column(\User.DatabaseModel.$id, as: "userID")
//            .column(.keyPath(\User.DatabaseModel.username, as: "username"))
//            .column(.function("sum", [.expression(.column(\TaskResult.DatabaseModel.resultScore))]), as: "totalScore")
//            .from(User.DatabaseModel.self)
//            .join(\User.DatabaseModel.id, to: \TaskResult.DatabaseModel.userID)
//            .groupBy(\User.DatabaseModel.id)
//            .all(decoding: UserResultOverview.self)
    }

    public static func getAllResults(for userId: User.ID, with database: Database) throws -> EventLoopFuture<[TaskResult]> {

        guard let sqlDB = database as? SQLDatabase else {
            return database.eventLoop.future(error: Abort(.internalServerError))
        }
        return database.eventLoop.future(error: Abort(.notImplemented))

//        conn.databaseConnection(to: .psql)
//            .flatMap { psqlConn in
//
//                psqlConn.select()
//                    .all(table: TaskResult.DatabaseModel.self)
//                    .where(
//                        .column(.keyPath(\TaskResult.DatabaseModel.id)),
//                        .in,
//                        .subquery(.raw(Query.taskResults.rawQuery, binds: [userId]))
//                    )
//                    .orderBy(\TaskResult.DatabaseModel.revisitDate)
//                    .all(decoding: TaskResult.self)
//        }
    }

    public static func getSpaceRepetitionTask(for userID: User.ID, sessionID: PracticeSession.ID, on database: Database) throws -> EventLoopFuture<SpaceRepetitionTask?> {

        return try Query.flowTasks(
            userID: userID,
            sessionID: sessionID
        )
            .query(for: database)
            .all(decoding: SpaceRepetitionTask.self)
            .map { tasks in
                let uncompletedTasks = tasks.filter { $0.sessionID != sessionID }
                let now = Date()
                let timeInADay: TimeInterval = 60 * 60 * 24

                return Dictionary(grouping: uncompletedTasks) { task in Int(now.timeIntervalSince(task.revisitDate) / timeInADay) }
                .filter { $0.key < 10 }
                .min { first, second in
                    first.key > second.key
                }?.value.randomElement()
        }
    }

//    public static func getAllResults<A>(for userId: User.ID, filter: FilterOperator<PostgreSQLDatabase, A>, with database: Database, maxRevisitDays: Int? = 10) throws -> EventLoopFuture<[TaskResult]> {
//
//        let oneDayAgo = Date(timeIntervalSinceNow: -60*60*24*3)
//
//        return try Query.results(
//            revisitingAfter: oneDayAgo,
//            for: userId
//        )
//            .query(for: conn)
//            .all(decoding: SubqueryResult.self)
//            .flatMap { result in
//
//                let ids = result.map { $0.id }
//
//                var query = TaskResult.DatabaseModel.query(on: conn)
//                    .filter(\.id ~~ ids)
//                    .filter(filter)
//                    .sort(\.revisitDate)
//                    .join(\Task.id, to: \TaskResult.DatabaseModel.taskID)
//                    .join(\Subtopic.DatabaseModel.id, to: \Task.subtopicID)
//                    .join(\Topic.DatabaseModel.id, to: \Subtopic.DatabaseModel.topicID)
//
//                if let maxRevisitDays = maxRevisitDays,
//                    let maxRevisitDaysDate = Calendar.current.date(byAdding: .day, value: maxRevisitDays, to: Date()) {
//                    query = query
//                        .filter(\TaskResult.DatabaseModel.revisitDate < maxRevisitDaysDate)
//                }
//
//                return query.all()
//                    .map { try $0.map { try $0.content() } }
//        }
//    }

    public static func getAllResultsContent(for user: User, with database: Database, limit: Int = 2) throws -> EventLoopFuture<[TopicResultContent]> {

        guard let sqlDB = database as? SQLDatabase else {
            return database.eventLoop.future(error: Abort(.internalServerError))
        }
        return database.eventLoop.future(error: Abort(.notImplemented))

//        return try Query.results(
//            revisitingAfter: Date(),
//            for: user.id
//        )
//            .query(for: conn)
//            .all(decoding: SubqueryResult.self)
//            .flatMap { result in
//
//                let ids = result.map { $0.id }
//                return TaskResult.DatabaseModel.query(on: conn)
//                    .filter(\.id ~~ ids)
//                    .sort(\.revisitDate, .ascending)
//                    .join(\Task.id, to: \TaskResult.DatabaseModel.taskID)
//                    .join(\Subtopic.DatabaseModel.id, to: \Task.subtopicID)
//                    .join(\Topic.DatabaseModel.id, to: \Subtopic.DatabaseModel.topicID)
//                    .join(\Subject.DatabaseModel.id, to: \Topic.DatabaseModel.subjectId)
//                    .alsoDecode(Topic.DatabaseModel.self)
//                    .alsoDecode(Subject.DatabaseModel.self)
//                    .range(...limit)
//                    .all()
//                    .map { contens in
//
//                        var responses: [Topic.ID: TopicResultContent] = [:]
//
//                        for content in contens {
//                            let result = content.0.0
//                            let topic = content.0.1
//
//                            if let response = try responses[topic.requireID()] {
//                                try responses[topic.requireID()] = TopicResultContent(results: response.results + [result.content()], topic: topic.content(), subject: content.1.content())
//                            } else {
//                                try responses[topic.requireID()] = TopicResultContent(results: [result.content()], topic: topic.content(), subject: content.1.content())
//                            }
//                        }
//                        return responses.map { $0.value }
//                            .sorted(by: { $0.revisitDate < $1.revisitDate })
//                }
//        }
    }

    public static func getAmountHistory(for user: User, on database: Database, numberOfWeeks: Int = 4) throws -> EventLoopFuture<[TaskResult.History]> {

        guard let sqlDB = database as? SQLDatabase else {
            return database.eventLoop.future(error: Abort(.internalServerError))
        }

        return sqlDB.select()
            .count(\TaskResult.DatabaseModel.$id, as: "numberOfTasksCompleted")
            .date(part: .year, from: \TaskResult.DatabaseModel.$createdAt, as: "year")
            .date(part: .week, from: \TaskResult.DatabaseModel.$createdAt, as: "week")
            .from(TaskResult.DatabaseModel.schema)
            .where("userID", .equal, user.id)
            .groupBy("year")
            .groupBy("week")
            .all(decoding: TaskResult.History.self)
            .flatMapThrowing { days in

//        let dateThreshold = Calendar.current.date(byAdding: .weekOfYear, value: -numberOfWeeks, to: Date()) ??
//            Date().addingTimeInterval(-7 * 24 * 60 * 60 * Double(numberOfWeeks)) // Four weeks back
//
//        return conn.select()
//            .column(.count(\TaskResult.DatabaseModel.id), as: "numberOfTasksCompleted")
//            .column(.function("date_part", [.expression(.literal("year")), .expression(.column(.keyPath(\TaskResult.DatabaseModel.createdAt)))]), as: "year")
//            .column(.function("date_part", [.expression(.literal("week")), .expression(.column(.keyPath(\TaskResult.DatabaseModel.createdAt)))]), as: "week")
//            .from(TaskResult.DatabaseModel.self)
//            .where(\TaskResult.DatabaseModel.userID == user.id)
//            .where(\TaskResult.DatabaseModel.createdAt, .greaterThanOrEqual, dateThreshold)
//            .groupBy(.column(.column(nil, "year")))
//            .groupBy(.column(.column(nil, "week")))
//            .all(decoding: TaskResult.History.self)
//            .map { days in
//                // FIXME: - there is a bug where the database uses one loale and the formatter another and this can leed to incorrect grouping
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

    public static func getAmountHistory(for user: User, in subjectId: Subject.ID, on database: Database, numberOfWeeks: Int = 4) throws -> EventLoopFuture<[TaskResult.History]> {

        guard let sqlDB = database as? SQLDatabase else {
            return database.eventLoop.future(error: Abort(.internalServerError))
        }

//        let dateThreshold = Calendar.current.date(byAdding: .weekOfYear, value: -numberOfWeeks, to: Date()) ??
//            Date().addingTimeInterval(-7 * 24 * 60 * 60 * Double(numberOfWeeks)) // Four weeks back

        return sqlDB.select()
            .count(\TaskResult.DatabaseModel.$id, as: "numberOfTasksCompleted")
            .date(part: .year, from: \TaskResult.DatabaseModel.$createdAt, as: "year")
            .date(part: .week, from: \TaskResult.DatabaseModel.$createdAt, as: "week")
            .from(TaskResult.DatabaseModel.schema)
            .join(from: \TaskResult.DatabaseModel.$task.$id, to: \TaskDatabaseModel.$id)
            .join(from: \TaskDatabaseModel.$subtopic.$id, to: \Subtopic.DatabaseModel.$id)
            .join(from: \Subtopic.DatabaseModel.$topic.$id, to: \Topic.DatabaseModel.$id)
            .where("userID", .equal, user.id)
            .where("subtopicId", .equal, subjectId)
            .groupBy("year")
            .groupBy("week")
            .all(decoding: TaskResult.History.self)
            .flatMapThrowing { days in
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
//
//        return conn.select()
//            .column(.count(\TaskResult.DatabaseModel.id), as: "numberOfTasksCompleted")
//            .column(.function("date_part", [.expression(.literal("year")), .expression(.column(.keyPath(\TaskResult.DatabaseModel.createdAt)))]), as: "year")
//            .column(.function("date_part", [.expression(.literal("week")), .expression(.column(.keyPath(\TaskResult.DatabaseModel.createdAt)))]), as: "week")
//            .from(TaskResult.DatabaseModel.self)
//            .join(\TaskResult.DatabaseModel.taskID, to: \TaskDatabaseModel.id)
//            .join(\TaskDatabaseModel.subtopicID, to: \Subtopic.DatabaseModel.id)
//            .join(\Subtopic.DatabaseModel.topicID, to: \Topic.DatabaseModel.id)
//            .where(\TaskResult.DatabaseModel.userID == user.id)
//            .where(\TaskResult.DatabaseModel.createdAt, .greaterThanOrEqual, dateThreshold)
//            .where(\Topic.DatabaseModel.subjectId == subjectId)
//            .groupBy(.column(.column(nil, "year")))
//            .groupBy(.column(.column(nil, "week")))
//            .all(decoding: TaskResult.History.self)
//        }
    }

    static func createResult(from result: TaskSubmitResultRepresentable, userID: User.ID, with sessionID: TaskSession.IDValue, on database: Database) -> EventLoopFuture<TaskResult> {
        let result = TaskResult.DatabaseModel(result: result, userID: userID, sessionID: sessionID)
        return result.save(on: database)
            .flatMapThrowing { try result.content() }
    }

    public static func getUserLevel(for userId: User.ID, in topics: [Topic.ID], on database: Database) throws -> EventLoopFuture<[User.TopicLevel]> {

        guard let sqlDB = database as? SQLDatabase else {
            return database.eventLoop.future(error: Abort(.internalServerError))
        }

        return try Query.resultsInTopics(topics, for: userId)
            .query(for: database)
            .all(decoding: SubqueryTopicResult.self)
            .flatMap { _ in

                return sqlDB.select()
                    .column(\TaskResult.DatabaseModel.$resultScore, as: "resultScore")
                    .column(\Topic.DatabaseModel.$id, as: "topicID")
                    .from(TaskResult.DatabaseModel.schema)
                    .join(parent: \TaskResult.DatabaseModel.$task)
                    .join(parent: \TaskDatabaseModel.$subtopic)
                    .join(parent: \Subtopic.DatabaseModel.$topic)
                    .all(decoding: UserLevelScore.self)
                    .flatMap { scores in
                        return scores.group(by: \UserLevelScore.topicID)
                            .map { topicID, grouped in

                                TaskDatabaseModel.query(on: database)
                                    .join(parent: \TaskDatabaseModel.$subtopic)
                                    .filter(Subtopic.DatabaseModel.self, \Subtopic.DatabaseModel.$topic.$id == topicID)
                                    .count()
                                    .map { maxScore in
                                        User.TopicLevel(
                                            topicID: topicID,
                                            correctScore: grouped.reduce(0) { $0 + $1.resultScore.clamped(to: 0...1) },
                                            maxScore: Double(maxScore)
                                        )
                                }
                        }.flatten(on: database.eventLoop)
                }
        }
    }

    public static func getUserLevel(in subject: Subject, userId: User.ID, on database: Database) throws -> EventLoopFuture<User.SubjectLevel> {

        return try Query.resultsInSubject(subject.id, for: userId)
            .query(for: database)
            .all(decoding: SubqueryResult.self)
            .flatMap { result in

                let ids = result.map { $0.id }

                guard ids.isEmpty == false else {
                    return database.eventLoop.future(
                        User.SubjectLevel(subjectID: subject.id, correctScore: 0, maxScore: 1)
                    )
                }

                return TaskResult.DatabaseModel.query(on: database)
                    .filter(\.$id ~~ ids)
                    .sum(\.$resultScore)
                    .flatMap { score in

                        TaskDatabaseModel.query(on: database)
                            .join(parent: \TaskDatabaseModel.$subtopic)
                            .join(parent: \Subtopic.DatabaseModel.$topic)
                            .filter(Topic.DatabaseModel.self, \Topic.DatabaseModel.$subject.$id == subject.id)
                            .count()
                            .map { maxScore in

                                User.SubjectLevel(
                                    subjectID: subject.id,
                                    correctScore: score ?? 0,
                                    maxScore: Double(maxScore)
                                )
                        }
                }
        }
    }

    public static func getLastResult(for taskID: Task.ID, by userId: User.ID, on database: Database) throws -> EventLoopFuture<TaskResult?> {
        return TaskResult.DatabaseModel.query(on: database)
            .filter(\TaskResult.DatabaseModel.$task.$id == taskID)
            .filter(\TaskResult.DatabaseModel.$user.$id == userId)
            .sort(\.$createdAt, .descending)
            .first()
            .flatMapThrowing { try $0?.content() }
    }

    public static func exportResults(on database: Database) throws -> EventLoopFuture<[TaskResult.Answer]> {

        guard let sqlDB = database as? SQLDatabase else {
            return database.eventLoop.future(error: Abort(.internalServerError))
        }
        return database.eventLoop.future(error: Abort(.notImplemented))
//        let query = #"SELECT "TaskResult".*, "FlashCardAnswer".*, "MultipleChoiseTaskAnswer".* FROM "TaskResult" FULL OUTER JOIN "FlashCardAnswer" ON "FlashCardAnswer"."taskID" = "TaskResult"."taskID" AND "FlashCardAnswer"."sessionID" = "TaskResult"."sessionID" LEFT JOIN "MultipleChoiseTaskChoise" ON "TaskResult"."taskID" = "MultipleChoiseTaskChoise"."taskId" FULL OUTER JOIN "MultipleChoiseTaskAnswer" ON "MultipleChoiseTaskAnswer"."choiseID" = "MultipleChoiseTaskChoise"."id" AND "MultipleChoiseTaskChoise"."taskId" = "TaskResult"."taskID" AND "MultipleChoiseTaskAnswer"."sessionID" = "TaskResult"."sessionID" ORDER BY "createdAt" DESC;"#
//
//        return conn.databaseConnection(to: .psql)
//            .flatMap { psqlConn in
//
//                psqlConn.raw(query)
//                    .all(decoding: TaskResult.self, MultipleChoiseTaskAnswer?.self, FlashCardAnswer?.self)
//                    .map { results in
//                        results
//                            .map { (result, multiple, flash) in
//                                TaskResult.Answer(
//                                    result: result,
//                                    multiple: multiple,
//                                    flash: flash
//                                )
//                        }
//                }
//                .map(Set.init)
//                .map(Array.init)
//        }
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
            lhs.result.id == rhs.result.id && lhs.multiple?.$choice.id == rhs.multiple?.$choice.id
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(result.id)
            hasher.combine(multiple?.$choice.id)
        }

        let result: TaskResult
        let multiple: MultipleChoiseTaskAnswer?
        let flash: FlashCardAnswer?
    }
}
