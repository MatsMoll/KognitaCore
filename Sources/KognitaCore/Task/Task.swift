//
//  Task.swift
//  App
//
//  Created by Mats Mollestad on 07/10/2018.
//

import Vapor
import FluentPostgreSQL

public final class Task: PostgreSQLModel {

    /// The semester a exam was taken
    ///
    /// - fall: The fall
    /// - spring: The spring
    public enum ExamSemester: String, PostgreSQLEnum, PostgreSQLMigration {
        case fall
        case spring

        var norwegianDescription: String {
            switch self {
            case .fall:     return "Høst"
            case .spring:   return "Vår"
            }
        }
    }

    public var id: Int?

    /// The topic.id for the topic this task relates to
    public var topicId: Topic.ID

    /// Some html that contains extra information about the task if needed
    public var description: String?

    /// The question needed to answer the task
    public var question: String

    /// A soulution to the task (May be changed to support multiple solutions)
    public var solution: String?

    /// The id of the user who created the task
    public var creatorId: User.ID

    /// The semester of the exam
    public var examPaperSemester: ExamSemester?

    /// The year of the exam
    public var examPaperYear: Int?

    /// A bool containing the info if the task may be used in a exam / test
    public var isExaminable: Bool

    /// The date the task was created at
    public var createdAt: Date?

    /// The date the task was updated at
    /// - Note: Usually a task will be marked as isOutdated and create a new `Task` when updated
    public var updatedAt: Date?


    public var deletedAt: Date?

    /// The id of the new edited task if there exists one
    public var editedTaskID: Task.ID?

    public static var createdAtKey: TimestampKey? = \.createdAt
    public static var updatedAtKey: TimestampKey? = \.updatedAt
    public static var deletedAtKey: TimestampKey? = \.deletedAt


    init(
        topicId: Topic.ID,
        estimatedTime: TimeInterval,
        description: String,
        imageURL: String?,
        explenation: String?,
        question: String,
        creatorId: User.ID,
        examPaperSemester: ExamSemester? = nil,
        examPaperYear: Int? = nil,
        isExaminable: Bool = true
    ) {
        self.topicId        = topicId
        self.solution       = explenation
        self.description    = description
        self.question       = question
        self.creatorId      = creatorId
        self.isExaminable   = isExaminable
        if examPaperSemester != nil, examPaperYear != nil {
            self.examPaperYear  = examPaperYear
            self.examPaperSemester = examPaperSemester
        }
    }

    init(
        content: TaskCreationContentable,
        topic: Topic,
        creator: User,
        canAnswer: Bool = true
    ) throws {
        self.topicId        = try topic.requireID()
        self.description    = content.description
        self.question       = content.question
        self.solution       = content.solution
        self.isExaminable   = content.isExaminable
        self.creatorId      = try creator.requireID()
        self.examPaperSemester = content.examPaperSemester
        self.examPaperYear  = content.examPaperYear

        validate()
    }

    func validate() {
        description?.makeHTMLSafe()
        question.makeHTMLSafe()
        solution?.makeHTMLSafe()
    }

    func taskContent(_ req: Request) -> Future<TaskContent> {
        return topic.get(on: req).flatMap { topic in
            topic.subject.get(on: req).flatMap { subject in
                try self.getTaskTypePath(req).map { path in
                    TaskContent(task: self, topic: topic, subject: subject, creator: nil, taskTypePath: path)
                }
            }
        }
    }

    static func taskContent(where filter: FilterOperator<PostgreSQLDatabase, Task>, on conn: DatabaseConnectable) -> Future<[TaskContent]> {
        return Task.query(on: conn)
            .filter(filter)
            .join(\Topic.id, to: \Task.topicId)
            .join(\Subject.id, to: \Topic.subjectId)
            .alsoDecode(Topic.self)
            .alsoDecode(Subject.self)
            .all().flatMap { tasks in
                return try tasks.map { (taskTopic, subject) in
                    try taskTopic.0.getTaskTypePath(conn).map { path in
                        TaskContent(task: taskTopic.0, topic: taskTopic.1, subject: subject, creator: nil, taskTypePath: path)
                    }
                }.flatten(on: conn)
        }
    }

    func getTaskTypePath(_ conn: DatabaseConnectable) throws -> Future<String> {
        return try TaskRepository.shared
            .getTaskTypePath(for: requireID(), conn: conn)
    }
}

extension Task {

    var topic: Parent<Task, Topic> {
        return parent(\.topicId)
    }

    var creator: Parent<Task, User> {
        return parent(\.creatorId)
    }
}

extension Task: Migration {
    public static func prepare(on conn: PostgreSQLConnection) -> Future<Void> {
        return PostgreSQLDatabase.create(Task.self, on: conn) { builder in
            try addProperties(to: builder)
            builder.reference(from: \.topicId, to: \Topic.id, onUpdate: .cascade, onDelete: .cascade)
            builder.reference(from: \.creatorId, to: \User.id, onUpdate: .cascade, onDelete: .cascade)
        }
    }

    public static func revert(on connection: PostgreSQLConnection) -> Future<Void> {
        return PostgreSQLDatabase.delete(Task.self, on: connection)
    }
}

extension Task: Content { }
extension Task: Parameter { }
