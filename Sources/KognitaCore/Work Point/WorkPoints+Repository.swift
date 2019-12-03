//
//  WorkPoint+Repository.swift
//  KognitaCore
//
//  Created by Mats Mollestad on 25/09/2019.
//

import Vapor
import FluentPostgreSQL

extension WorkPoints {
    public final class Repository: KognitaRepository {
        public typealias Model = WorkPoints
    }

    public struct Create: KognitaRequestData {
        public typealias Data = TaskResult
        public typealias Response = WorkPoints
    }

    public struct LeaderboardRank: Codable {
        public let userName: String
        public let userID: User.ID
        public let pointsSum: Int
        public let rank: Int
    }
}

extension WorkPoints.Repository {
    public static func create(from content: TaskResult, by user: User?, on conn: DatabaseConnectable) throws -> EventLoopFuture<WorkPoints> {

        guard let user = user else { throw Abort(.unauthorized) }
        guard try content.userID == user.requireID() else { throw Abort(.forbidden) }

        return try WorkPoints(taskResult: content, boostAmount: 1)
            .save(on: conn)
    }

    public static func leaderboard(for user: User, amount: Int = 5, on conn: DatabaseConnectable) throws -> EventLoopFuture<[WorkPoints.LeaderboardRank]> {

        return conn.databaseConnection(to: .psql)
            .flatMap { psqlConn in

                var encodableBindings: [Encodable] = []
                let leaderboardQuery = psqlConn.select()
                    .column(\WorkPoints.userID)
                    .column(.sum(\WorkPoints.points), as: "pointsSum")
                    .from(WorkPoints.self)
                    .groupBy(\WorkPoints.userID)
                    .orderBy(.column(.column(nil, "pointsSum")), .descending)
                    .query.serialize(&encodableBindings)

                let query = "WITH \"leaderboard\" AS (SELECT \"lead\".\"userID\", \"lead\".\"pointsSum\", ROW_NUMBER() OVER () AS \"rank\" FROM (\(leaderboardQuery)) AS \"lead\") SELECT \"User\".\"name\" AS \"userName\", \"userID\", \"pointsSum\", \"rank\" FROM \"leaderboard\" JOIN \"User\" ON \"leaderboard\".\"userID\" = \"User\".\"id\" LIMIT ($2) OFFSET GREATEST(0, (SELECT \"rank\" FROM \"leaderboard\" WHERE \"userID\" = ($1)) - ($3));"

                return try psqlConn.raw(query)
                    .bind(user.requireID())
                    .bind(amount)
                    .bind(amount / 2 + 1)
                    .all(decoding: WorkPoints.LeaderboardRank.self)
        }
    }

    public static func leaderboard(in subject: Subject, for user: User, amount: Int = 5, on conn: DatabaseConnectable) throws -> EventLoopFuture<[WorkPoints.LeaderboardRank]> {

        return conn.databaseConnection(to: .psql)
            .flatMap { psqlConn in

                var encodableBindings: [Encodable] = []
                let leaderboardQuery = try psqlConn.select()
                    .column(\WorkPoints.userID)
                    .column(.sum(\WorkPoints.points), as: "pointsSum")
                    .from(WorkPoints.self)
                    .join(\WorkPoints.taskResultID, to: \TaskResult.id)
                    .join(\TaskResult.taskID, to: \Task.id)
                    .join(\Task.subtopicId, to: \Subtopic.id)
                    .join(\Subtopic.topicId, to: \Topic.id)
                    .where(\Topic.subjectId == subject.requireID())
                    .groupBy(\WorkPoints.userID)
                    .orderBy(.column(.column(nil, "pointsSum")), .descending)
                    .query.serialize(&encodableBindings)

                let query = "WITH \"leaderboard\" AS (SELECT \"lead\".\"userID\", \"lead\".\"pointsSum\", ROW_NUMBER() OVER () AS \"rank\" FROM (\(leaderboardQuery)) AS \"lead\") SELECT \"User\".\"name\" AS \"userName\", \"userID\", \"pointsSum\", \"rank\" FROM \"leaderboard\" JOIN \"User\" ON \"leaderboard\".\"userID\" = \"User\".\"id\" LIMIT ($2) OFFSET GREATEST(0, (SELECT \"rank\" FROM \"leaderboard\" WHERE \"userID\" = ($4)) - ($3));"

                return try psqlConn.raw(query)
                    .bind(subject.requireID())
                    .bind(amount)
                    .bind(amount / 2 + 1)
                    .bind(user.requireID())
                    .all(decoding: WorkPoints.LeaderboardRank.self)
        }
    }

    public static func leaderboard(in topic: Topic, for user: User, amount: Int = 5, on conn: DatabaseConnectable) throws -> EventLoopFuture<[WorkPoints.LeaderboardRank]> {

        return conn.databaseConnection(to: .psql)
            .flatMap { psqlConn in

                var encodableBindings: [Encodable] = []
                let leaderboardQuery = try psqlConn.select()
                    .column(\WorkPoints.userID)
                    .column(.sum(\WorkPoints.points), as: "pointsSum")
                    .from(WorkPoints.self)
                    .join(\WorkPoints.taskResultID, to: \TaskResult.id)
                    .join(\TaskResult.taskID, to: \Task.id)
                    .join(\Task.subtopicId, to: \Subtopic.id)
                    .where(\Subtopic.topicId == topic.requireID())
                    .groupBy(\WorkPoints.userID)
                    .orderBy(.column(.column(nil, "pointsSum")), .descending)
                    .query.serialize(&encodableBindings)

                let query = "WITH \"leaderboard\" AS (SELECT \"lead\".\"userID\", \"lead\".\"pointsSum\", ROW_NUMBER() OVER () AS \"rank\" FROM (\(leaderboardQuery)) AS \"lead\") SELECT \"User\".\"name\" AS \"userName\", \"userID\", \"pointsSum\", \"rank\" FROM \"leaderboard\" JOIN \"User\" ON \"leaderboard\".\"userID\" = \"User\".\"id\" LIMIT ($2) OFFSET GREATEST(0, (SELECT \"rank\" FROM \"leaderboard\" WHERE \"userID\" = ($1)) - ($3));"

                return try psqlConn.raw(query)
                    .bind(topic.requireID())
                    .bind(amount)
                    .bind(amount / 2 + 1)
                    .bind(user.requireID())
                    .all(decoding: WorkPoints.LeaderboardRank.self)
        }
    }
}
