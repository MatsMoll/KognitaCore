//
//  Task.swift
//  App
//
//  Created by Mats Mollestad on 07/10/2018.
//

import Vapor
import FluentPostgreSQL

/// The superclass of all task types
public final class Task: KognitaPersistenceModel {

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

    var topicId: Topic.ID?

    /// The topic.id for the topic this task relates to
    public var subtopicId: Subtopic.ID

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

    public static var deletedAtKey: TimestampKey? = \.deletedAt


    init(
        subtopicId: Subtopic.ID,
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
        self.subtopicId     = subtopicId
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
        subtopic: Subtopic,
        creator: User,
        canAnswer: Bool = true
    ) throws {
        self.subtopicId     = try subtopic.requireID()
        self.description    = content.description
        self.question       = content.question
        self.solution       = content.solution
        self.isExaminable   = content.isExaminable
        self.creatorId      = try creator.requireID()
        self.examPaperSemester = content.examPaperSemester
        self.examPaperYear  = content.examPaperYear

        validate()
    }

    public static func addTableConstraints(to builder: SchemaCreator<Task>) {
        builder.reference(from: \.subtopicId, to: \Subtopic.id, onUpdate: .cascade, onDelete: .cascade)
        builder.reference(from: \.creatorId, to: \User.id, onUpdate: .cascade, onDelete: .cascade)
    }
}

extension Task {

    var subtopic: Parent<Task, Subtopic> {
        return parent(\.subtopicId)
    }

    var creator: Parent<Task, User> {
        return parent(\.creatorId)
    }
    
    func validate() {
        description?.makeHTMLSafe()
        question.makeHTMLSafe()
        solution?.makeHTMLSafe()
    }

    func taskContent(_ req: Request) -> Future<TaskContent> {
        return topic(on: req)
            .flatMap { topic in
                topic.subject
                    .get(on: req)
                    .flatMap { subject in
                        try self.getTaskTypePath(req).map { path in
                            TaskContent(task: self, topic: topic, subject: subject, creator: nil, taskTypePath: path)
                        }
                }
        }
    }

    static func taskContent(where filter: FilterOperator<PostgreSQLDatabase, Task>, on conn: DatabaseConnectable) -> Future<[TaskContent]> {
        return Task.query(on: conn)
            .filter(filter)
            .join(\Subtopic.id, to: \Task.subtopicId)
            .join(\Topic.id, to: \Subtopic.topicId)
            .join(\Subject.id, to: \Topic.subjectId)
            .alsoDecode(Topic.self)
            .alsoDecode(Subject.self)
            .all()
            .flatMap { tasks in
                return try tasks.map { (taskTopic, subject) in
                    try taskTopic.0.getTaskTypePath(conn).map { path in
                        TaskContent(task: taskTopic.0, topic: taskTopic.1, subject: subject, creator: nil, taskTypePath: path)
                    }
                }.flatten(on: conn)
        }
    }

    func getTaskTypePath(_ conn: DatabaseConnectable) throws -> Future<String> {
        return try Task.Repository
            .getTaskTypePath(for: requireID(), conn: conn)
    }

    func topic(on conn: DatabaseConnectable) -> Future<Topic> {
        return Topic.query(on: conn)
            .join(\Subtopic.topicId, to: \Topic.id)
            .filter(\Subtopic.id == subtopicId)
            .first()
            .unwrap(or: Abort(.internalServerError))
    }
}

extension Task: Content { }
extension Task: Parameter { }
