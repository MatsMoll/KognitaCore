//
//  TaskResultRepository.swift
//  KognitaCore
//
//  Created by Mats Mollestad on 12/04/2019.
//

import FluentPostgreSQL
import FluentSQL

public class TaskResultRepository {

    public static let shared = TaskResultRepository()

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

    private let getTasksQuery = "SELECT DISTINCT ON (\"taskID\") \"TaskResult\".\"id\", \"taskID\" FROM \"TaskResult\" INNER JOIN \"Task\" ON \"TaskResult\".\"taskID\" = \"Task\".\"id\" WHERE \"TaskResult\".\"userID\" = ($1) AND \"Task\".\"deletedAt\" IS NULL ORDER BY \"taskID\", \"TaskResult\".\"createdAt\" DESC"

    private let getTasksQueryTopicFilter = "SELECT DISTINCT ON (\"TaskResult\".\"taskID\") \"TaskResult\".\"id\", \"TaskResult\".\"taskID\", \"Topic\".\"id\" AS \"topicID\" FROM \"TaskResult\" INNER JOIN \"Task\" ON \"TaskResult\".\"taskID\" = \"Task\".\"id\" INNER JOIN \"Subtopic\" ON \"Task\".\"subtopicId\" = \"Subtopic\".\"id\" INNER JOIN \"Topic\" ON \"Subtopic\".\"topicId\" = \"Topic\".\"id\" WHERE \"Task\".\"deletedAt\" IS NULL AND \"userID\" = ($1) AND \"Topic\".\"id\" = ANY($2) ORDER BY \"TaskResult\".\"taskID\", \"TaskResult\".\"createdAt\" DESC"

    private let getTasksQuerySubjectFilter = "SELECT DISTINCT ON (\"TaskResult\".\"taskID\") \"TaskResult\".\"id\", \"TaskResult\".\"taskID\" FROM \"TaskResult\" INNER JOIN \"Task\" ON \"TaskResult\".\"taskID\" = \"Task\".\"id\" INNER JOIN \"Subtopic\" ON \"Task\".\"subtopicId\" = \"Subtopic\".\"id\" INNER JOIN \"Topic\" ON \"Subtopic\".\"topicId\" = \"Topic\".\"id\" INNER JOIN \"Subject\" ON \"Subject\".\"id\" = \"Topic\".\"subjectId\" WHERE \"Task\".\"deletedAt\" IS NULL AND \"userID\" = ($1) AND \"Subject\".\"id\" = ($2) ORDER BY \"TaskResult\".\"taskID\", \"TaskResult\".\"createdAt\" DESC"


    public func getAllResults(for userId: User.ID, with conn: PostgreSQLConnection) throws -> Future<[TaskResult]> {

        return conn.select()
            .all(table: TaskResult.self)
            .where(
                .column(.keyPath(\TaskResult.id)),
                .in,
                .subquery(.raw(getTasksQuery, binds: [userId]))
            )
            .orderBy(\TaskResult.revisitDate)
            .all(decoding: TaskResult.self)
    }

    public func getAllResults<A>(for userId: User.ID, filter: FilterOperator<PostgreSQLDatabase, A>, with conn: PostgreSQLConnection, maxRevisitDays: Int? = 10) throws -> Future<[TaskResult]> {

        return conn.raw(getTasksQuery)
            .bind(userId)
            .all(decoding: SubqueryResult.self)
            .flatMap { result in

                let ids = result.map { $0.id }

                var query = TaskResult.query(on: conn)
                    .filter(\.id ~~ ids)
                    .filter(filter)
                    .sort(\.revisitDate)
                    .join(\Task.id, to: \TaskResult.taskID)
                    .join(\Subtopic.id, to: \Task.subtopicId)
                    .join(\Topic.id, to: \Subtopic.topicId)

                if let maxRevisitDays = maxRevisitDays,
                    let maxRevisitDaysDate = Calendar.current.date(byAdding: .day, value: maxRevisitDays, to: Date()) {
                    query = query
                        .filter(\TaskResult.revisitDate < maxRevisitDaysDate)
                }

                return query.all()
        }
    }

    public func getAllResultsContent(for user: User, with conn: PostgreSQLConnection, limit: Int = 6) throws -> Future<[TopicResultContent]> {

        return try conn.raw(getTasksQuery)
            .bind(user.requireID())
            .all(decoding: SubqueryResult.self).flatMap { result in

                let ids = result.map { $0.id }
                return TaskResult.query(on: conn)
                    .filter(\.id ~~ ids)
                    .sort(\.revisitDate, .ascending)
                    .join(\Task.id, to: \TaskResult.taskID)
                    .join(\Subtopic.id, to: \Task.subtopicId)
                    .join(\Topic.id, to: \Subtopic.topicId)
                    .join(\Subject.id, to: \Topic.subjectId)
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
                        return responses.map { $0.value }.sorted(by: { $0.revisitDate < $1.revisitDate })
                }
        }
    }

    public func getAmountHistory(for user: User, on conn: PostgreSQLConnection, numberOfDays: Int = 7) throws -> Future<[TaskResult.History]> {

        let weekAgo = Calendar.current.date(byAdding: .weekOfYear, value: -1, to: Date()) ??
            Date().addingTimeInterval(-7 * 24 * 60 * 60) // One week back

        return try conn.select()
            .column(.count(\TaskResult.id), as: "numberOfTasksCompleted")
            .column(.function("date", [.expression(.column(.keyPath(\TaskResult.createdAt)))]), as: "date")
            .from(TaskResult.self)
            .where(\TaskResult.userID == user.requireID())
            .where(\TaskResult.createdAt, .greaterThanOrEqual, weekAgo)
            .groupBy(.function("date", [.expression(.column(.keyPath(\TaskResult.createdAt)))]))
            .all(decoding: TaskResult.History.self)
            .map { days in
                // FIXME: - there is a bug where the database uses one loale and the formatter another and this can leed to incorrect grouping
                let now = Date()
                let formatter = DateFormatter()
                formatter.dateFormat = "dd-MM-yyyy"

                var data = [String : TaskResult.History]()

                (0...(numberOfDays - 1)).forEach {
                    let date = Calendar.current.date(byAdding: .day, value: -$0, to: now) ??
                        now.addingTimeInterval(-TimeInterval($0) * 24 * 60 * 60)

                    data[formatter.string(from: date)] = TaskResult.History(
                        numberOfTasksCompleted: 0,
                        date: date
                    )
                }

                for day in days {
                    data[formatter.string(from: day.date)] = day
                }
                return data.map { $1 }
                    .sorted(by: { $0.date < $1.date })
        }
    }

    func createResult(from result: TaskSubmitResult, by user: User, on conn: DatabaseConnectable, in session: PracticeSession? = nil) throws -> Future<TaskResult> {
        return try TaskResult(result: result, userID: user.requireID(), session: session)
            .save(on: conn)
    }

    public func getUserLevel(for userId: User.ID, in topics: [Topic.ID], on conn: PostgreSQLConnection) throws -> Future<[User.TopicLevel]> {

        return conn.raw(getTasksQueryTopicFilter)
            .bind(userId)
            .bind(topics)
            .all(decoding: SubqueryTopicResult.self)
            .flatMap { result in

                let ids = result.map { $0.id }

                return conn.select()
                    .column(.column(\TaskResult.resultScore), as: "resultScore")
                    .column(.column(\Topic.id), as: "topicID")
                    .from(TaskResult.self)
                    .where(\TaskResult.id, .in, ids)
                    .join(\TaskResult.taskID, to: \Task.id)
                    .join(\Task.subtopicId, to: \Subtopic.id)
                    .join(\Subtopic.topicId, to: \Topic.id)
                    .all(decoding: UserLevelScore.self)
                    .flatMap { scores in

                        return scores.group(by: \UserLevelScore.topicID)
                            .map { topicID, grouped in

                            Task.query(on: conn)
                                .join(\Subtopic.id, to: \Task.subtopicId)
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

    public func getUserLevel(in subject: Subject, userId: User.ID, on conn: PostgreSQLConnection) throws -> Future<User.SubjectLevel> {

        return try conn.raw(getTasksQuerySubjectFilter)
            .bind(userId)
            .bind(subject.requireID())
            .all(decoding: SubqueryResult.self)
            .flatMap { result in

                let ids = result.map { $0.id }

                guard ids.isEmpty == false else {
                    return conn.future(
                        try User.SubjectLevel(subjectID: subject.requireID(), correctScore: 0, maxScore: 1)
                    )
                }

                return TaskResult.query(on: conn)
                    .filter(\.id ~~ ids)
                    .sum(\.resultScore)
                    .flatMap { score in

                        try Task.query(on: conn)
                            .join(\Subtopic.id, to: \Task.subtopicId)
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

    public func getLastResult(for taskID: Task.ID, by user: User, on conn: DatabaseConnectable) throws -> Future<TaskResult?> {
        return try TaskResult.query(on: conn)
            .filter(\TaskResult.taskID == taskID)
            .filter(\TaskResult.userID == user.requireID())
            .sort(\.createdAt, .descending)
            .first()
    }


    public func getResults(on conn: PostgreSQLConnection) -> Future<[UserResultOverview]> {

        return conn.select()
            .column(.count(.all, as: "resultCount"))
            .column(.keyPath(\User.id, as: "userID"))
            .column(.keyPath(\User.name, as: "userName"))
            .column(.function("sum", [.expression(.column(\TaskResult.resultScore))]), as: "totalScore")
            .from(User.self)
            .join(\User.id, to: \TaskResult.userID)
            .groupBy(\User.id)
            .all(decoding: UserResultOverview.self)
    }
}

struct TaskSubmitResult {
    public let submit: TaskSubmitable
    public let result: TaskSubmitResultable
    public let taskID: Task.ID
}

extension User {
    public struct TopicLevel {
        public let topicID: Topic.ID
        public let correctScore: Double
        public let maxScore: Double

        public var correctScoreInteger: Int { return Int(correctScore.rounded()) }
        public var correctProsentage: Double {
            return (correctScore * 1000 / maxScore).rounded() / 10
        }
    }

    public struct SubjectLevel {
        public let subjectID: Subject.ID
        public let correctScore: Double
        public let maxScore: Double

        public var correctScoreInteger: Int { return Int(correctScore.rounded()) }
        public var correctProsentage: Double {
            return (correctScore * 1000 / maxScore).rounded() / 10
        }
    }
}
