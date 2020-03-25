//
//  PracticeSessionRepository.swift
//  KognitaCore
//
//  Created by Mats Mollestad on 12/04/2019.
//

import FluentPostgreSQL
import FluentSQL
import Vapor


public protocol PracticeSessionRepository:
    CreateModelRepository
    where
    CreateData == PracticeSession.Create.Data,
    CreateResponse == PracticeSession.Create.Response
{
    static func getSessions(for user: User, on conn: DatabaseConnectable) throws -> EventLoopFuture<[PracticeSession.HighOverview]>
    static func extend(session: PracticeSessionRepresentable, for user: User, on conn: DatabaseConnectable) throws -> EventLoopFuture<Void>
}


extension PracticeSession {
    public final class DatabaseRepository {}
}

extension PracticeSession.DatabaseRepository: PracticeSessionRepository {

    public enum Errors: Error {
        case noAssignedTask
        case nextTaskNotAssigned
        case incorrectTaskType
        case noMoreTasks
    }

    public static func create(
        from content: PracticeSession.Create.Data,
        by user: User?,
        on conn: DatabaseConnectable
    ) throws -> EventLoopFuture<PracticeSession.Create.Response> {

        guard let user = user else {
            throw Abort(.unauthorized)
        }

        if let topicIDs = content.topicIDs {
            return Subject.DatabaseRepository
                .subjectIDFor(topicIDs: Array(topicIDs), on: conn)
                .flatMap { subjectID in

                    try User.DatabaseRepository
                        .canPractice(user: user, subjectID: subjectID, on: conn)
                        .flatMap {

                            try create(
                                topicIDs: topicIDs,
                                numberOfTaskGoal: content.numberOfTaskGoal,
                                user: user,
                                on: conn
                            )
                    }
            }
        } else if let subtopicIDs = content.subtopicsIDs {

            return Subject.DatabaseRepository
                .subjectIDFor(subtopicIDs: Array(subtopicIDs), on: conn)
                .flatMap { subjectID in

                    try User.DatabaseRepository
                        .canPractice(user: user, subjectID: subjectID, on: conn)
                        .flatMap {

                            try create(
                                subtopicIDs: subtopicIDs,
                                numberOfTaskGoal: content.numberOfTaskGoal,
                                user: user,
                                on: conn
                            )
                    }
            }
        } else {
            throw Abort(.badRequest)
        }
    }

    static func create(
        topicIDs: Set<Topic.ID>,
        numberOfTaskGoal: Int,
        user: User,
        on conn: DatabaseConnectable
    ) throws -> EventLoopFuture<PracticeSession.Create.Response> {

        guard topicIDs.count > 0 else {
            throw Abort(.badRequest)
        }
        return topicIDs.map {
            Subtopic.DatabaseRepository
                .subtopics(with: $0, on: conn)
        }
        .flatten(on: conn)
        .flatMap { subtopics in
            let subtopicIDs = Set(subtopics.flatMap { $0 }.compactMap { $0.id })
            return try create(subtopicIDs: subtopicIDs, numberOfTaskGoal: numberOfTaskGoal, user: user, on: conn)
        }
    }

    static func create(
        subtopicIDs: Set<Subtopic.ID>,
        numberOfTaskGoal: Int,
        user: User,
        on conn: DatabaseConnectable
    ) throws -> EventLoopFuture<PracticeSession.Create.Response> {

        guard subtopicIDs.count > 0 else {
            throw Abort(.badRequest)
        }
        return conn.transaction(on: .psql) { conn in

            try TaskSession(userID: user.requireID())
                .create(on: conn)
                .flatMap { superSession in

                    try PracticeSession(sessionID: superSession.requireID(), numberOfTaskGoal: numberOfTaskGoal)
                        .create(on: conn)
                        .flatMap { session in

                            try subtopicIDs.map {
                                try PracticeSession.Pivot.Subtopic(subtopicID: $0, session: session)
                                    .create(on: conn)
                                }
                                .flatten(on: conn)
                                .flatMap { _ in

                                    try assignTask(to: session.representable(with: superSession), on: conn)
                                        .transform(to: session)
                            }
                        }
            }
        }
    }
    
    public static func subtopics(
        in session: PracticeSessionRepresentable,
        on conn: DatabaseConnectable
    ) throws -> EventLoopFuture<[Subtopic]> {

        return try PracticeSession.Pivot.Subtopic
            .query(on: conn)
            .filter(\.sessionID == session.requireID())
            .join(\Subtopic.id, to: \PracticeSession.Pivot.Subtopic.subtopicID)
            .decode(Subtopic.self)
            .all()
    }
    
    public static func assignedTasks(
        in session: PracticeSessionRepresentable,
        on conn: DatabaseConnectable
    ) throws -> EventLoopFuture<[Task]> {

        return try PracticeSession.Pivot.Task
            .query(on: conn)
            .filter(\.sessionID == session.requireID())
            .join(\Task.id, to: \PracticeSession.Pivot.Task.taskID)
            .decode(Task.self)
            .all()
    }
    
    static func uncompletedTasks(
        in session: PracticeSessionRepresentable,
        on conn: DatabaseConnectable
    ) throws -> EventLoopFuture<SessionTasks> {

        return try subtopics(in: session, on: conn)
            .flatMap { subtopics in
            
                try PracticeSession.DatabaseRepository
                    .assignedTasks(in: session, on: conn)
                    .flatMap { assignedTasks in
                        
                        try Task.query(on: conn)
                            .filter(
                                FilterOperator.make(
                                    \Task.id,
                                    PostgreSQLDatabase.queryFilterMethodNotInSubset,
                                    assignedTasks.map { try $0.requireID() }
                                )
                            )
                            .filter(\.subtopicID ~~ subtopics.map { try $0.requireID() })
                            .filter(\.isTestable == false)
                            .all()
                            .map { uncompletedTasks in
                                
                                SessionTasks(
                                    uncompletedTasks: uncompletedTasks,
                                    assignedTasks: assignedTasks
                                )
                        }
                }
        }
    }
    
    public static func assignTask(
        to session: PracticeSessionRepresentable,
        on conn: DatabaseConnectable
    ) throws -> EventLoopFuture<Void> {

        return conn.databaseConnection(to: .psql).flatMap { psqlConn in

            // 1/3 chanse of assigning a random task
            if Int.random(in: 1...3) == 3 {
                return try PracticeSession.DatabaseRepository
                    .assignUncompletedTask(to: session, on: psqlConn)
            } else {
                return try TaskResult.DatabaseRepository
                    .getSpaceRepetitionTask(for: session, on: psqlConn)
                    .flatMap { repetitionTask in

                        guard let task = repetitionTask else {
                            return try PracticeSession.DatabaseRepository
                                .assignUncompletedTask(to: session, on: psqlConn)
                        }

                        return try PracticeSession.DatabaseRepository
                            .currentTaskIndex(in: session, on: psqlConn)
                            .flatMap { taskIndex in

                                try PracticeSession.Pivot.Task
                                    .create(session: session, taskID: task.taskID, index: taskIndex + 1, on: psqlConn)
                                    .transform(to: ())
                        }
                }
            }
        }
    }

    public static func assignUncompletedTask(
        to session: PracticeSessionRepresentable,
        on conn: DatabaseConnectable
    ) throws -> EventLoopFuture<Void> {

        return try uncompletedTasks(in: session, on: conn)
            .flatMap { tasks in

                guard let task = tasks.uncompletedTasks.randomElement() else {
                    throw Errors.noMoreTasks
                }

                return try PracticeSession.Pivot.Task
                    .create(session: session, task: task, index: tasks.assignedTasks.count + 1, on: conn)
                    .transform(to: ())
        }
    }

    public static func currentTaskIndex(
        in session: PracticeSessionRepresentable,
        on conn: DatabaseConnectable
    ) throws -> EventLoopFuture<Int> {

        return try TaskResult.query(on: conn)
            .filter(\.sessionID == session.requireID())
            .count()
    }
    
    public static func currentActiveTask(
        in session: PracticeSession,
        on conn: PostgreSQLConnection
    ) throws -> EventLoopFuture<TaskType> {

        return try conn.select()
            .all(table: Task.self)
            .all(table: MultipleChoiseTask.self)
            .from(PracticeSession.Pivot.Task.self)
            .where(\PracticeSession.Pivot.Task.sessionID == session.requireID())
            .orderBy(\PracticeSession.Pivot.Task.index, .descending)
            .join(\PracticeSession.Pivot.Task.taskID, to: \Task.id)
            .join(\Task.id, to: \MultipleChoiseTask.id, method: .left)
            .first(decoding: Task.self, MultipleChoiseTask?.self)
            .unwrap(or: Abort(.internalServerError))
            .map { taskContent in
                TaskType(content: taskContent)
        }
    }

    public static func taskAt(
        index: Int,
        in sessionID: PracticeSession.ID,
        on conn: PostgreSQLConnection
    ) throws -> EventLoopFuture<TaskType> {

        return conn.select()
            .all(table: Task.self)
            .all(table: MultipleChoiseTask.self)
            .from(PracticeSession.Pivot.Task.self)
            .where(\PracticeSession.Pivot.Task.sessionID == sessionID)
            .where(\PracticeSession.Pivot.Task.index == index)
            .orderBy(\PracticeSession.Pivot.Task.index, .descending)
            .join(\PracticeSession.Pivot.Task.taskID, to: \Task.id)
            .join(\Task.id, to: \MultipleChoiseTask.id, method: .left)
            .first(decoding: Task.self, MultipleChoiseTask?.self)
            .unwrap(or: Abort(.badRequest))
            .map { taskContent in
                TaskType(content: taskContent)
        }
    }

    public static func taskID(
        index: Int,
        in sessionID: PracticeSession.ID,
        on conn: DatabaseConnectable
    ) -> EventLoopFuture<Task.ID> {

        PracticeSession.Pivot.Task
            .query(on: conn)
            .filter(\.index == index)
            .filter(\.sessionID == sessionID)
            .first()
            .unwrap(or: Abort(.badRequest))
            .map { $0.taskID }
    }
}

extension PracticeSession.DatabaseRepository {

    public static func submit(
        _ submit: MultipleChoiseTask.Submit,
        in session: PracticeSessionRepresentable,
        by user: User,
        on conn: DatabaseConnectable
    ) throws -> EventLoopFuture<TaskSessionResult<[MultipleChoiseTaskChoise.Result]>> {

        guard try user.requireID() == session.userID else {
            throw Abort(.forbidden)
        }

        return try get(MultipleChoiseTask.self, at: submit.taskIndex, for: session, on: conn).flatMap { task in

            try MultipleChoiseTask.DatabaseRepository
                .create(answer: submit, sessionID: session.requireID(), on: conn)
                .flatMap { _ in

                    try MultipleChoiseTask.DatabaseRepository
                        .evaluate(submit.choises, for: task, on: conn)
                        .flatMap { result in

                            let submitResult = try TaskSubmitResult(
                                submit: submit,
                                result: result,
                                taskID: task.requireID()
                            )

                            return try PracticeSession.DatabaseRepository
                                .register(submitResult, result: result, in: session, by: user, on: conn)
                                .flatMap { _ in

                                    try goalProgress(in: session, on: conn)
                                        .map { progress in
                                            result.progress = Double(progress)
                                            return result
                                    }
                            }
                    }
            }
        }
    }

    public static func submit(
        _ submit: FlashCardTask.Submit,
        in session: PracticeSessionRepresentable,
        by user: User,
        on conn: DatabaseConnectable
    ) throws -> EventLoopFuture<TaskSessionResult<FlashCardTask.Submit>> {

        guard try user.requireID() == session.userID else {
            throw Abort(.forbidden)
        }
        
        return try get(FlashCardTask.self, at: submit.taskIndex, for: session, on: conn).flatMap { task in

            FlashCardTask.DatabaseRepository
                .createAnswer(for: task, with: submit, on: conn)
                .flatMap { answer in

                    try update(submit, in: session, on: conn)
                        .map { _ in
                            TaskSessionResult(result: submit, score: 0, progress: 0)
                    }
                    .catchFlatMap { _ in
                        try PracticeSession.DatabaseRepository
                            .save(answer: answer, to: session.requireID(), on: conn)
                            .flatMap {

                                let score = ScoreEvaluater.shared
                                    .compress(score: submit.knowledge, range: 0...4)

                                let result = TaskSessionResult(
                                    result:     submit,
                                    score:      score,
                                    progress:   0
                                )

                                let submitResult = try TaskSubmitResult(
                                    submit: submit,
                                    result: result,
                                    taskID: task.requireID()
                                )

                                return try PracticeSession.DatabaseRepository
                                    .register(submitResult, result: result, in: session, by: user, on: conn)
                                    .flatMap { _ in

                                        try goalProgress(in: session, on: conn)
                                            .map { progress in
                                                result.progress = Double(progress)
                                                return result
                                        }
                                }
                        }
                    }
            }
        }
    }

    public static func update(_ submit: FlashCardTask.Submit, in session: PracticeSessionRepresentable, on conn: DatabaseConnectable) throws -> EventLoopFuture<Void> {
        try PracticeSession.Pivot.Task.query(on: conn)
            .filter(\TaskResult.sessionID                   == session.requireID())
            .filter(\PracticeSession.Pivot.Task.sessionID   == session.requireID())
            .filter(\PracticeSession.Pivot.Task.index       == submit.taskIndex)
            .join(\TaskResult.taskID,   to: \PracticeSession.Pivot.Task.taskID)
            .join(\FlashCardTask.id,    to: \TaskResult.taskID)
            .decode(TaskResult.self)
            .first()
            .unwrap(or: Abort(.badRequest))
            .flatMap { (result: TaskResult) in
                result.resultScore = ScoreEvaluater.shared.compress(score: submit.knowledge, range: 0...4)
                return result.save(on: conn)
                    .transform(to: ())
        }
    }

    public static func get<T: PostgreSQLModel>(
        _ taskType: T.Type,
        at index: Int,
        for session: PracticeSessionRepresentable,
        on conn: DatabaseConnectable
    ) throws -> EventLoopFuture<T> {
        
        return try PracticeSession.Pivot.Task
            .query(on: conn)
            .filter(\PracticeSession.Pivot.Task.sessionID == session.requireID())
            .filter(\PracticeSession.Pivot.Task.index == index)
            .sort(\PracticeSession.Pivot.Task.index, .descending)
            .join(\T.id, to: \PracticeSession.Pivot.Task.taskID)
            .decode(T.self)
            .first()
            .unwrap(or: Abort(.badRequest))
    }

    static func markAsComplete(
        taskID: Task.ID,
        in session: PracticeSessionRepresentable,
        on conn: DatabaseConnectable
    ) throws -> EventLoopFuture<Void> {

        return try PracticeSession.Pivot.Task
            .query(on: conn)
            .filter(\.sessionID == session.requireID())
            .filter(\PracticeSession.Pivot.Task.taskID == taskID)
            .first()
            .unwrap(or: Abort(.internalServerError, reason: "Unable to find pivot when registering submit"))
            .flatMap { pivot in
                pivot.isCompleted = true
                return pivot
                    .save(on: conn)
                    .flatMap { _ in

                        try assignTask(to: session, on: conn)
                }
        }
    }

    public static func end(
        _ session: PracticeSessionRepresentable,
        for user: User,
        on conn: DatabaseConnectable
    ) throws -> EventLoopFuture<PracticeSessionRepresentable> {

        guard try session.userID == user.requireID() else {
            throw Abort(.forbidden)
        }

        guard session.endedAt == nil else {
            return conn.future(session)
        }
        return session.end(on: conn)
    }

    public static func goalProgress(
        in session: PracticeSessionRepresentable,
        on conn: DatabaseConnectable
    ) throws -> EventLoopFuture<Int> {

        let goal = Double(session.numberOfTaskGoal)

        return try PracticeSession.Pivot.Task
            .query(on: conn)
            .filter(\.sessionID == session.requireID())
            .filter(\.isCompleted == true)
            .count()
            .map { (numberOfCompletedTasks) in
                Int((Double(numberOfCompletedTasks * 100) / goal).rounded())
        }
    }

    public static func getCurrentTaskIndex(
        for sessionId: PracticeSession.ID,
        on conn: DatabaseConnectable
    ) throws -> EventLoopFuture<Int> {
        
        return PracticeSession.Pivot.Task
            .query(on: conn)
            .filter(\PracticeSession.Pivot.Task.sessionID == sessionId)
            .sort(\PracticeSession.Pivot.Task.index, .descending)
            .first()
            .unwrap(or: Abort(.badRequest))
            .map { task in
                task.index
        }
    }

    public static func getResult(
        for sessionID: PracticeSession.ID,
        on conn: DatabaseConnectable
    ) throws -> EventLoopFuture<[PracticeSession.TaskResult]> {

        return conn.databaseConnection(to: .psql)
            .flatMap { conn in

                conn.select()
                    .column(\Topic.name,                        as: "topicName")
                    .column(\Topic.id,                          as: "topicID")
                    .column(\PracticeSession.Pivot.Task.index,  as: "taskIndex")
                    .column(\TaskResult.createdAt,              as: "date")
                    .column(\Task.question,                     as: "question")
                    .column(\TaskResult.resultScore,            as: "score")
                    .column(\TaskResult.timeUsed,               as: "timeUsed")
                    .column(\TaskResult.revisitDate,            as: "revisitDate")
                    .from(PracticeSession.Pivot.Task.self)
                    .join(\PracticeSession.Pivot.Task.taskID, to: \Task.id)
                    .join(\Task.subtopicID, to: \Subtopic.id)
                    .join(\Subtopic.topicId, to: \Topic.id)
                    .join(\Task.id, to: \TaskResult.taskID)
                    .where(\TaskResult.sessionID == sessionID)
                    .where(\PracticeSession.Pivot.Task.sessionID == sessionID)
                    .all(decoding: PracticeSession.TaskResult.self)
        }
    }

    public static func getAllSessions(
        by user: User,
        on conn: DatabaseConnectable
    ) throws -> EventLoopFuture<[PracticeSession]> {

        return try PracticeSession
            .query(on: conn)
            .join(\TaskSession.id, to: \PracticeSession.id)
            .filter(\TaskSession.userID == user.requireID())
            .filter(\PracticeSession.endedAt != nil)
            .sort(\PracticeSession.createdAt, .descending)
            .all()
    }

    public static func getAllSessionsWithSubject(
        by user: User,
        on conn: PostgreSQLConnection
    ) throws -> EventLoopFuture<PracticeSession.HistoryList> {

        return try conn.select()
            .all(table: PracticeSession.self)
            .all(table: Subject.self)
            .from(PracticeSession.self)
            .join(\PracticeSession.id, to: \TaskSession.id)
            .join(\PracticeSession.id, to: \PracticeSession.Pivot.Subtopic.sessionID)
            .join(\PracticeSession.Pivot.Subtopic.subtopicID, to: \Subtopic.id)
            .join(\Subtopic.topicId, to: \Topic.id)
            .join(\Topic.subjectId, to: \Subject.id)
            .where(\PracticeSession.endedAt != nil)
            .where(\TaskSession.userID == user.requireID())
            .orderBy(\PracticeSession.createdAt, .descending)
            .groupBy(\PracticeSession.id)
            .groupBy(\Subject.id)
            .all(decoding: PracticeSession.self, Subject.self)
            .map { sessions in
                PracticeSession.HistoryList(
                    sessions: sessions.map { item in
                        PracticeSession.HistoryList.Session(
                            session: item.0,
                            subject: item.1
                        )
                    }
                )
        }
    }

    public static func getSessions(for user: User, on conn: DatabaseConnectable) throws -> EventLoopFuture<[PracticeSession.HighOverview]> {

        conn.databaseConnection(to: .psql)
            .flatMap { conn in

                try conn.select()
                    .column(\Subject.name,              as: "subjectName")
                    .column(\Subject.id,                as: "subjectID")
                    .column(\PracticeSession.id,        as: "id")
                    .column(\PracticeSession.createdAt, as: "createdAt")
                    .from(PracticeSession.self)
                    .join(\PracticeSession.id,      to: \TaskSession.id)
                    .join(\PracticeSession.id,      to: \PracticeSession.Pivot.Subtopic.sessionID)
                    .join(\PracticeSession.Pivot.Subtopic.subtopicID, to: \Subtopic.id)
                    .join(\Subtopic.topicId,        to: \Topic.id)
                    .join(\Topic.subjectId,         to: \Subject.id)
                    .where(\PracticeSession.endedAt != nil)
                    .where(\TaskSession.userID == user.requireID())
                    .orderBy(\PracticeSession.createdAt, .descending)
                    .groupBy(\PracticeSession.id)
                    .groupBy(\Subject.id)
                    .all(decoding: PracticeSession.HighOverview.self)
        }
    }

    static func register<T: Content>(
        _ submitResult: TaskSubmitResult,
        result: TaskSessionResult<T>,
        in session: PracticeSessionRepresentable,
        by user: User,
        on conn: DatabaseConnectable
    ) throws -> EventLoopFuture<TaskResult> {

        return try TaskResult.DatabaseRepository
            .createResult(from: submitResult, userID: user.requireID(), with: session.requireID(), on: conn)
            .flatMap { result in

                try PracticeSession.DatabaseRepository
                    .markAsComplete(taskID: submitResult.taskID, in: session, on: conn)
                    .catchFlatMap { error in
                        switch error {
                        case PracticeSession.DatabaseRepository.Errors.noMoreTasks: return conn.future()
                        default: return conn.future(error: error)
                        }
                }.transform(to: result)
        }
    }


    public static func cleanSessions(on conn: DatabaseConnectable) -> EventLoopFuture<Void> {

        return PracticeSession.query(on: conn)
            .filter(\.endedAt == nil)
            .all()
            .flatMap { sessions in
                sessions.map { session in
                    TaskResult.query(on: conn)
                        .filter(\.sessionID == session.id)
                        .sort(\.createdAt, .descending)
                        .first()
                        .flatMap { result in
                            guard let createdAt = result?.createdAt else {
                                return session.delete(on: conn)
                            }
                            session.endedAt = createdAt
                            return session.save(on: conn)
                                .transform(to: ())
                    }
                }.flatten(on: conn)
        }
    }


    public static func getLatestUnfinnishedSessionPath(
        for user: User,
        on conn: DatabaseConnectable
    ) throws -> EventLoopFuture<String?> {

        return try PracticeSession.query(on: conn)
            .join(\TaskSession.id, to: \PracticeSession.id)
            .filter(\TaskSession.userID == user.requireID())
            .filter(\PracticeSession.endedAt == nil)
            .sort(\PracticeSession.createdAt, .descending)
            .first()
            .flatMap { session in

                if let session = session {
                    return try session
                        .getCurrentTaskIndex(conn)
                        .map(to: String?.self) { try session.pathFor(index: $0) }
                } else {
                    return conn.future(nil)
                }

        }
    }

    /// Returns the number of tasks in a session
    public static func getNumberOfTasks(
        in session: PracticeSession,
        on conn: DatabaseConnectable
    ) throws -> EventLoopFuture<Int> {

        return try PracticeSession.Pivot.Subtopic.query(on: conn)
            .join(\Task.subtopicID, to: \PracticeSession.Pivot.Subtopic.subtopicID)
            .filter(\PracticeSession.Pivot.Subtopic.sessionID == session.requireID())
            .count()
    }

    public static func save(answer: TaskAnswer, to sessionID: PracticeSession.ID, on conn: DatabaseConnectable) throws -> EventLoopFuture<Void> {
        try TaskSessionAnswer(
            sessionID: sessionID,
            taskAnswerID: answer.requireID()
        )
        .create(on: conn)
        .transform(to: ())
    }

    public static func extend(session: PracticeSessionRepresentable, for user: User, on conn: DatabaseConnectable) throws -> EventLoopFuture<Void> {
        guard try session.userID == user.requireID() else {
            throw Abort(.forbidden)
        }
        return session.extendSession(with: 5, on: conn)
            .transform(to: ())
    }
}

struct SessionTasks {
    let uncompletedTasks: [Task]
    let assignedTasks: [Task]
}
