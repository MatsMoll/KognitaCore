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
    public struct DatabaseRepository: TaskResultRepositoring {

        let database: Database

        public init(database: Database) {
            self.database = database
        }
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

    private struct RecommendedTopics: Codable {
        let topicID: Topic.ID
        let revisitAt: Date
    }

    private enum Query {

        case subtopics
        case taskResults
        case spaceRepetitionTask(userID: User.ID, sessionID: PracticeSession.ID, useTypingTasks: Bool, useMultipleChoiceTasks: Bool)
        case recommendedTopics(userID: User.ID, lowerDate: Date, upperDate: Date, limit: Int)
        case results(revisitingAfter: Date, for: User.ID)
        case resultsInSubject(Subject.ID, for: User.ID)
        case resultsInTopics([Topic.ID], for: User.ID)
        case resultsInTopicsBetweenDates([Topic.ID], for: User.ID, lowerDate: Date, upperDate: Date)

        var rawQuery: SQLQueryString {
            switch self {
            case .subtopics: return #"SELECT "PracticeSession_Subtopic"."subtopicID" FROM "PracticeSession_Subtopic" WHERE "PracticeSession_Subtopic"."sessionID" = ($2)"#
            case .taskResults: return #"SELECT DISTINCT ON ("taskID") * FROM "TaskResult" WHERE "TaskResult"."userID" = ($1) ORDER BY "taskID", "TaskResult"."createdAt" DESC"#
            case .spaceRepetitionTask(let userID, let sessionID, let useTypingTasks, let useMultipleChoiceTasks):

                var taskTypeJoin = ""
                switch (useTypingTasks, useMultipleChoiceTasks) {
                case (true, true): break
                case (false, true): taskTypeJoin = #" INNER JOIN "\#(MultipleChoiceTask.DatabaseModel.schema)" ON "Task"."id"="\#(MultipleChoiceTask.DatabaseModel.schema)"."id" "#
                case (true, false): taskTypeJoin = #" INNER JOIN "FlashCardTask" ON "Task"."id"="FlashCardTask"."id" "#
                default: break
                }

                return #"SELECT DISTINCT ON ("TaskResult"."taskID") "TaskResult"."taskID", "TaskResult"."createdAt" AS "createdAt", "TaskResult"."revisitDate", "TaskResult"."sessionID" FROM "TaskResult" INNER JOIN "Task" ON "TaskResult"."taskID" = "Task"."id"\#(raw: taskTypeJoin) WHERE "Task"."deletedAt" IS NULL AND "TaskResult"."revisitDate" IS NOT NULL AND "TaskResult"."userID" = \#(bind: userID) AND "Task"."subtopicID" = ANY (SELECT "PracticeSession_Subtopic"."subtopicID" FROM "PracticeSession_Subtopic" WHERE "Task"."isTestable" = 'false' AND "PracticeSession_Subtopic"."sessionID" = \#(bind: sessionID)) ORDER BY "TaskResult"."taskID" DESC, "TaskResult"."createdAt" DESC"#
            case .results:
                return #"SELECT DISTINCT ON ("taskID") "TaskResult"."id", "taskID" FROM "TaskResult" INNER JOIN "Task" ON "TaskResult"."taskID" = "Task"."id" WHERE "TaskResult"."userID" = ($1) AND "Task"."deletedAt" IS NULL AND "TaskResult"."revisitDate" > ($2) ORDER BY "taskID", "TaskResult"."createdAt" DESC"#
            case .resultsInTopics(let topicIDs, let userID):
                return #"SELECT DISTINCT ON ("TaskResult"."taskID") "TaskResult"."id", "TaskResult"."taskID", "Topic"."id" AS "topicID" FROM "TaskResult" INNER JOIN "Task" ON "TaskResult"."taskID" = "Task"."id" INNER JOIN "Subtopic" ON "Task"."subtopicID" = "Subtopic"."id" INNER JOIN "Topic" ON "Subtopic"."topicID" = "Topic"."id" WHERE "Task"."deletedAt" IS NULL AND "userID" = \#(bind: userID) AND "Topic"."id" = ANY(\#(bind: topicIDs)) ORDER BY "TaskResult"."taskID", "TaskResult"."createdAt" DESC"#
            case .resultsInSubject(let subjectID, let userID):
                return #"SELECT DISTINCT ON ("TaskResult"."taskID") "TaskResult"."id", "TaskResult"."taskID" FROM "TaskResult" INNER JOIN "Task" ON "TaskResult"."taskID" = "Task"."id" INNER JOIN "Subtopic" ON "Task"."subtopicID" = "Subtopic"."id" INNER JOIN "Topic" ON "Subtopic"."topicID" = "Topic"."id" INNER JOIN "Subject" ON "Subject"."id" = "Topic"."subjectID" WHERE "Task"."deletedAt" IS NULL AND "userID" = \#(bind: userID) AND "Subject"."id" = \#(bind: subjectID) ORDER BY "TaskResult"."taskID", "TaskResult"."createdAt" DESC"#
            case .recommendedTopics(let userID, let lowerDate, let upperDate, let limit):
                return """
                    SELECT * FROM (
                    SELECT DISTINCT ON ("topicID") *
                    FROM (
                    SELECT DISTINCT ON ("TaskResult"."taskID") "TaskResult"."taskID", "TaskResult"."createdAt" AS "createdAt", "TaskResult"."revisitDate" AS "revisitAt", "Subtopic"."topicID" AS "topicID"
                    FROM "TaskResult"
                    INNER JOIN "Task" ON "TaskResult"."taskID" = "Task"."id"
                    INNER JOIN "Subtopic" ON "Subtopic"."id" = "Task"."subtopicID"
                    WHERE "Task"."deletedAt" IS NULL AND "TaskResult"."revisitDate" IS NOT NULL
                    AND "TaskResult"."userID" = \(bind: userID)
                    AND "Task"."isTestable" = 'false'
                    ORDER BY "TaskResult"."taskID" DESC, "TaskResult"."createdAt" DESC
                    ) TaskResult
                    WHERE TaskResult."revisitAt" < \(bind: upperDate)
                    AND TaskResult."revisitAt" > \(bind: lowerDate)
                    ) TaskResult
                    ORDER BY TaskResult."revisitAt"
                    LIMIT \(bind: limit)
                    """
            case .resultsInTopicsBetweenDates(let topicIDs, let userID, let lowerDate, let upperDate):
                return #"SELECT DISTINCT ON ("TaskResult"."taskID") "TaskResult"."id", "TaskResult"."taskID", "Topic"."id" AS "topicID" FROM "TaskResult" INNER JOIN "Task" ON "TaskResult"."taskID" = "Task"."id" INNER JOIN "Subtopic" ON "Task"."subtopicID" = "Subtopic"."id" INNER JOIN "Topic" ON "Subtopic"."topicID" = "Topic"."id" WHERE "Task"."deletedAt" IS NULL AND "TaskResult"."revisitDate" < \#(bind: upperDate) AND "TaskResult"."revisitDate" > \#(bind: lowerDate) AND "userID" = \#(bind: userID) AND "Topic"."id" = ANY(\#(bind: topicIDs)) ORDER BY "TaskResult"."taskID", "TaskResult"."createdAt" DESC"#
            }
        }

        func query(for database: Database) throws -> SQLRawBuilder {

            guard let sqlDB = database as? SQLDatabase else {
                throw Abort(.internalServerError)
            }
            switch self {
            case .resultsInSubject, .spaceRepetitionTask, .results, .resultsInTopics, .recommendedTopics, .resultsInTopicsBetweenDates:
                return sqlDB.raw(self.rawQuery)
            case .subtopics, .taskResults:
                throw Errors.incompleateSqlStatment
            }
        }
    }

    public func getResults() -> EventLoopFuture<[UserResultOverview]> {

        guard let sqlDB = database as? SQLDatabase else {
            return database.eventLoop.future(error: Abort(.internalServerError))
        }
        return sqlDB.select()
            .column(SQLAlias(SQLFunction("COUNT", args: SQLLiteral.all), as: SQLIdentifier("resultCount")))
            .column(\User.DatabaseModel.$id, as: "userID")
            .column(\User.DatabaseModel.$username, as: "username")
            .sum(\TaskResult.DatabaseModel.$resultScore, as: "totalScore")
            .from(User.DatabaseModel.schema)
            .join(from: \User.DatabaseModel.$id, to: \TaskResult.DatabaseModel.$user.$id)
            .groupBy(\User.DatabaseModel.$id)
            .orderBy("resultCount")
            .all(decoding: UserResultOverview.self)
    }

    public func getAllResults(for userId: User.ID) -> EventLoopFuture<[TaskResult]> {

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

    public func getSpaceRepetitionTask(for userID: User.ID, sessionID: PracticeSession.ID) -> EventLoopFuture<SpaceRepetitionTask?> {

        PracticeSession.DatabaseModel.find(sessionID, on: database)
            .unwrap(or: Abort(.badRequest))
            .failableFlatMap { session in

                try Query.spaceRepetitionTask(
                    userID: userID,
                    sessionID: sessionID,
                    useTypingTasks: session.useTypingTasks,
                    useMultipleChoiceTasks: session.useMultipleChoiceTasks
                )
                    .query(for: self.database)
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

    public func getAllResultsContent(for user: User, limit: Int = 2) -> EventLoopFuture<[TopicResultContent]> {

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

    public func getAmountHistory(for user: User, numberOfWeeks: Int = 4) -> EventLoopFuture<[TaskResult.History]> {

        guard let sqlDB = database as? SQLDatabase else {
            return database.eventLoop.future(error: Abort(.internalServerError))
        }

        let dateThreshold = Calendar.current.date(byAdding: .weekOfYear, value: -numberOfWeeks, to: Date()) ??
            Date().addingTimeInterval(-7 * 24 * 60 * 60 * Double(numberOfWeeks)) // Four weeks back

        return sqlDB.select()
            .count(\TaskResult.DatabaseModel.$id, as: "numberOfTasksCompleted")
            .date(part: .year, from: \TaskResult.DatabaseModel.$createdAt, as: "year")
            .date(part: .week, from: \TaskResult.DatabaseModel.$createdAt, as: "week")
            .from(TaskResult.DatabaseModel.schema)
            .where("userID", .equal, user.id)
            .where("createdAt", .greaterThanOrEqual, dateThreshold)
            .groupBy("year")
            .groupBy("week")
            .all(decoding: TaskResult.History.self)
            .flatMapThrowing { days in

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

    public func getAmountHistory(for user: User, in subjectId: Subject.ID, numberOfWeeks: Int = 4) -> EventLoopFuture<[TaskResult.History]> {

        guard let sqlDB = database as? SQLDatabase else {
            return database.eventLoop.future(error: Abort(.internalServerError))
        }

        let dateThreshold = Calendar.current.date(byAdding: .weekOfYear, value: -numberOfWeeks, to: Date()) ??
            Date().addingTimeInterval(-7 * 24 * 60 * 60 * Double(numberOfWeeks)) // Four weeks back

        return sqlDB.select()
            .count(\TaskResult.DatabaseModel.$id, as: "numberOfTasksCompleted")
            .date(part: .year, from: \TaskResult.DatabaseModel.$createdAt, as: "year")
            .date(part: .week, from: \TaskResult.DatabaseModel.$createdAt, as: "week")
            .from(TaskResult.DatabaseModel.schema)
            .join(from: \TaskResult.DatabaseModel.$task.$id, to: \TaskDatabaseModel.$id)
            .join(from: \TaskDatabaseModel.$subtopic.$id, to: \Subtopic.DatabaseModel.$id)
            .join(from: \Subtopic.DatabaseModel.$topic.$id, to: \Topic.DatabaseModel.$id)
            .where("userID", .equal, user.id)
            .where("subjectID", .equal, subjectId)
            .where(SQLColumn("createdAt", table: TaskResult.DatabaseModel.schemaOrAlias), .greaterThanOrEqual, SQLBind(dateThreshold))
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
    }

    public func createResult(from result: TaskSubmitResultRepresentable, userID: User.ID, with sessionID: Sessions.ID?) -> EventLoopFuture<TaskResult> {
        let result = TaskResult.DatabaseModel(result: result, userID: userID, sessionID: sessionID)
        return result.save(on: database)
            .flatMapThrowing { try result.content() }
    }

    public func updateResult(with result: TaskSubmitResultRepresentable, userID: User.ID, with sessionID: Sessions.ID?) -> EventLoopFuture<UpdateResultOutcom> {
        TaskResult.DatabaseModel.query(on: database)
            .filter(\.$task.$id == result.taskID)
            .filter(\.$session.$id == sessionID)
            .first()
            .failableFlatMap { savedResult in
                if let savedResult = savedResult {
                    savedResult.isSetManually = true
                    savedResult.resultScore = result.score.clamped(to: 0...1)

                    let numberOfDays = ScoreEvaluater.shared.daysUntillReview(score: savedResult.resultScore)
                    let interval = Double(numberOfDays) * 60 * 60 * 24
                    savedResult.revisitDate = Date().addingTimeInterval(interval)

                    let content = try savedResult.content()
                    return savedResult.save(on: database)
                        .transform(to: .updated(result: content))
                } else {
                    return createResult(from: result, userID: userID, with: sessionID)
                        .map { .created(result: $0) }
                }
            }
    }

    public func getUserLevel(for userId: User.ID, in topics: [Topic.ID]) -> EventLoopFuture<[Topic.UserLevel]> {

        guard topics.isEmpty == false else { return database.eventLoop.future([]) }
        guard let sqlDB = database as? SQLDatabase else {
            return database.eventLoop.future(error: Abort(.internalServerError))
        }

        return failable(eventLoop: database.eventLoop) {
            try Query.resultsInTopics(topics, for: userId)
                .query(for: database)
                .all(decoding: SubqueryTopicResult.self)
                .flatMap { results -> EventLoopFuture<[UserLevelScore]> in

                    guard results.isEmpty == false else {
                        return self.database.eventLoop.future([])
                    }
                    return sqlDB.select()
                        .column(\TaskResult.DatabaseModel.$resultScore, as: "resultScore")
                        .column(\Topic.DatabaseModel.$id, as: "topicID")
                        .from(TaskResult.DatabaseModel.schema)
                        .where(SQLColumn("id", table: TaskResult.DatabaseModel.schemaOrAlias), .in, SQLBind.group(results.map { $0.id }))
                        .join(parent: \TaskResult.DatabaseModel.$task)
                        .join(parent: \TaskDatabaseModel.$subtopic)
                        .join(parent: \Subtopic.DatabaseModel.$topic)
                        .all(decoding: UserLevelScore.self)
            }
        }
        .flatMap { scores in
            scores.group(by: \UserLevelScore.topicID)
                .map { topicID, grouped in

                    TaskDatabaseModel.query(on: self.database)
                        .join(parent: \TaskDatabaseModel.$subtopic)
                        .filter(Subtopic.DatabaseModel.self, \Subtopic.DatabaseModel.$topic.$id == topicID)
                        .count()
                        .map { maxScore in
                            Topic.UserLevel(
                                topicID: topicID,
                                correctScore: grouped.reduce(0) { $0 + $1.resultScore.clamped(to: 0...1) },
                                maxScore: Double(maxScore)
                            )
                    }
            }.flatten(on: self.database.eventLoop)
        }
    }

    public func getUserLevel(in subject: Subject, userId: User.ID) -> EventLoopFuture<User.SubjectLevel> {

        failable(eventLoop: database.eventLoop) {
            try Query.resultsInSubject(subject.id, for: userId)
                .query(for: database)
                .all(decoding: SubqueryResult.self)
                .flatMap { result in

                    let ids = result.map { $0.id }

                    guard ids.isEmpty == false else {
                        return self.database.eventLoop.future(
                            User.SubjectLevel(subjectID: subject.id, correctScore: 0, maxScore: 1)
                        )
                    }

                    return TaskResult.DatabaseModel.query(on: self.database)
                        .filter(\.$id ~~ ids)
                        .sum(\.$resultScore)
                        .flatMap { score in

                            TaskDatabaseModel.query(on: self.database)
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
    }

    public func getLastResult(for taskID: Task.ID, by userId: User.ID) -> EventLoopFuture<TaskResult?> {
        return TaskResult.DatabaseModel.query(on: database)
            .filter(\TaskResult.DatabaseModel.$task.$id == taskID)
            .filter(\TaskResult.DatabaseModel.$user.$id == userId)
            .sort(\.$createdAt, .descending)
            .first()
            .flatMapThrowing { try $0?.content() }
    }

    public func exportResults() -> EventLoopFuture<[TaskResult.Answer]> {

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

    public func getResult(for taskID: Task.ID, by userID: User.ID, sessionID: Int) -> EventLoopFuture<TaskResult?> {
        TaskResult.DatabaseModel.query(on: database)
            .filter(\.$session.$id == sessionID)
            .filter(\.$task.$id == taskID)
            .filter(\.$user.$id == userID)
            .first()
            .flatMapThrowing { try $0?.content() }
    }

    public func recommendedRecap(for userID: User.ID, upperBoundDays: Int, lowerBoundDays: Int, limit: Int) -> EventLoopFuture<[RecommendedRecap]> {

        let upperBoundDate = Calendar.current.date(byAdding: .day, value: upperBoundDays, to: .now) ?? .now
        let lowerBoundDate = Calendar.current.date(byAdding: .day, value: lowerBoundDays, to: .now) ?? .now

        return failable(eventLoop: database.eventLoop) {
            try Query.recommendedTopics(
                userID: userID,
                lowerDate: lowerBoundDate,
                upperDate: upperBoundDate,
                limit: limit
            )
                .query(for: database)
                .all(decoding: RecommendedTopics.self)
                .failableFlatMap { topics -> EventLoopFuture<[RecommendedRecap]> in

                    try Query.resultsInTopics(
                        topics.map { $0.topicID },
                        for: userID
                    )
                        .query(for: database)
                        .all(decoding: SubqueryTopicResult.self)
                        .flatMap { results -> EventLoopFuture<[RecommendedRecap]> in

                            guard results.isEmpty == false, let sqlDB = database as? SQLDatabase else {
                                return self.database.eventLoop.future([])
                            }
                            return sqlDB.select()
                                .column(\Topic.DatabaseModel.$id, as: "topicID")
                                .column(\Topic.DatabaseModel.$name, as: "topicName")
                                .column(\TaskResult.DatabaseModel.$resultScore, as: "resultScore")
                                .column(\Subject.DatabaseModel.$name, as: "subjectName")
                                .column(\Subject.DatabaseModel.$id, as: "subjectID")
                                .column(\TaskResult.DatabaseModel.$revisitDate, as: "revisitAt")
                                .from(TaskResult.DatabaseModel.schema)
                                .where(SQLColumn("id", table: TaskResult.DatabaseModel.schemaOrAlias), .in, SQLBind.group(results.map { $0.id }))
                                .join(parent: \TaskResult.DatabaseModel.$task)
                                .join(parent: \TaskDatabaseModel.$subtopic)
                                .join(parent: \Subtopic.DatabaseModel.$topic)
                                .join(parent: \Topic.DatabaseModel.$subject)
                                .all(decoding: RecommendedRecap.self)
                    }
                    .flatMap { scores -> EventLoopFuture<[RecommendedRecap]> in
                        scores.group(by: \.topicID)
                            .map { topicID, grouped -> EventLoopFuture<RecommendedRecap> in

                                TaskDatabaseModel.query(on: self.database)
                                    .join(parent: \TaskDatabaseModel.$subtopic)
                                    .filter(Subtopic.DatabaseModel.self, \Subtopic.DatabaseModel.$topic.$id == topicID)
                                    .count()
                                    .map { maxScore in
                                        RecommendedRecap(
                                            subjectName: grouped.first!.subjectName,
                                            subjectID: grouped.first!.subjectID,
                                            topicName: grouped.first!.topicName,
                                            topicID: topicID,
                                            resultScore: grouped.reduce(0) { $0 + $1.resultScore.clamped(to: 0...1) } / Double(maxScore),
                                            revisitAt: topics.first(where: { $0.topicID == topicID })!.revisitAt
                                        )
                                }
                        }
                        .flatten(on: database.eventLoop)
                        .map { $0.sorted(by: \.revisitAt, direction: .acending) }
                    }
                }
        }
    }
}

public protocol TaskSubmitResultRepresentable: TaskSubmitResultable, TaskSubmitable {
    var taskID: Task.ID { get }
}

struct TaskSubmitResultRepresentableWrapper: TaskSubmitResultRepresentable {
    let taskID: Int
    let score: Double
    let timeUsed: TimeInterval?
}

struct TaskSubmitResult: TaskSubmitResultRepresentable {
    public let submit: TaskSubmitable
    public let result: TaskSubmitResultable
    public let taskID: Task.ID

    var timeUsed: TimeInterval? { submit.timeUsed }
    var score: Double { result.score }
}

extension User {

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
