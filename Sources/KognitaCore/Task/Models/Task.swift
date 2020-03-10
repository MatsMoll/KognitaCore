//
//  Task.swift
//  App
//
//  Created by Mats Mollestad on 07/10/2018.
//

import Vapor
import FluentPostgreSQL

/// The superclass of all task types
public final class Task: KognitaPersistenceModel, SoftDeleatableModel {

    /// The semester a exam was taken
    ///
    /// - fall: The fall
    /// - spring: The spring
    public enum ExamSemester: String, PostgreSQLEnum, PostgreSQLMigration {
        case fall
        case spring

        public var norwegianDescription: String {
            switch self {
            case .fall:     return "Høst"
            case .spring:   return "Vår"
            }
        }
    }

    public var id: Int?

    /// The topic.id for the topic this task relates to
    public var subtopicID: Subtopic.ID

    /// Some markdown that contains extra information about the task if needed
    public var description: String?

    /// The question needed to answer the task
    public var question: String

    /// The id of the user who created the task
    public var creatorID: User.ID?

    /// The semester of the exam
    public var examPaperSemester: ExamSemester?

    /// The year of the exam
    public var examPaperYear: Int?

    /// If the task can be used for testing
    public var isTestable: Bool

    /// The date the task was created at
    public var createdAt: Date?

    /// The date the task was updated at
    /// - Note: Usually a task will be marked as isOutdated and create a new `Task` when updated
    public var updatedAt: Date?

    public var deletedAt: Date?

    /// The id of the new edited task if there exists one
    public var editedTaskID: Task.ID?


    init(
        subtopicID: Subtopic.ID,
        description: String?,
        question: String,
        creatorID: User.ID,
        examPaperSemester: ExamSemester? = nil,
        examPaperYear: Int? = nil,
        isTestable: Bool = false
    ) {
        self.subtopicID     = subtopicID
        self.description    = description
        self.question       = question
        self.creatorID      = creatorID
        self.isTestable     = isTestable
        if examPaperSemester != nil, examPaperYear != nil {
            self.examPaperYear  = examPaperYear
            self.examPaperSemester = examPaperSemester
        }
    }

    init(
        content: TaskCreationContentable,
        subtopicID: Subtopic.ID,
        creator: User,
        canAnswer: Bool = true
    ) throws {
        self.subtopicID     = subtopicID
        self.description    = try content.description?.cleanXSS(whitelist: .basicWithImages())
        self.question       = try content.question.cleanXSS(whitelist: .basicWithImages())
        self.isTestable     = content.isTestable
        self.creatorID      = try creator.requireID()
        self.examPaperSemester = content.examPaperSemester
        self.examPaperYear  = content.examPaperYear
    }

    public static func prepare(on conn: PostgreSQLConnection) -> EventLoopFuture<Void> {
        PostgreSQLDatabase.create(Task.self, on: conn) { builder in
            try addProperties(to: builder)

            builder.reference(from: \.subtopicID, to: \Subtopic.id, onUpdate: .cascade, onDelete: .cascade)
            builder.reference(from: \.creatorID, to: \User.id, onUpdate: .cascade, onDelete: .setDefault)
        }.flatMap {
            PostgreSQLDatabase.update(Task.self, on: conn) { builder in
                builder.deleteField(for: \.creatorID)
                builder.field(for: \.creatorID, type: .int, .default(1))
            }
        }
    }
}

extension Task {

    var subtopic: Parent<Task, Subtopic> {
        return parent(\.subtopicID)
    }

    var creator: Parent<Task, User>? {
        return parent(\.creatorID)
    }

    var betaFormatted: BetaFormat {
        BetaFormat(
            description: description,
            question: question,
            solution: nil,
            examPaperSemester: examPaperSemester,
            examPaperYear: examPaperYear,
            editedTaskID: editedTaskID
        )
    }

    func taskContent(_ req: Request) -> EventLoopFuture<TaskContent> {
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

    static func taskContent(where filter: FilterOperator<PostgreSQLDatabase, Task>, on conn: DatabaseConnectable) -> EventLoopFuture<[TaskContent]> {
        return Task.query(on: conn)
            .filter(filter)
            .join(\Subtopic.id, to: \Task.subtopicID)
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

    func getTaskTypePath(_ conn: DatabaseConnectable) throws -> EventLoopFuture<String> {
        return try Task.Repository
            .getTaskTypePath(for: requireID(), conn: conn)
    }

    func topic(on conn: DatabaseConnectable) -> Future<Topic> {
        return Topic.query(on: conn)
            .join(\Subtopic.topicId, to: \Topic.id)
            .filter(\Subtopic.id == subtopicID)
            .first()
            .unwrap(or: Abort(.internalServerError))
    }
}

extension Task: Content { }
extension Task: ModelParameterRepresentable { }


extension Task {
    public struct BetaFormat: Content {

        /// Some html that contains extra information about the task if needed
        public var description: String?

        /// The question needed to answer the task
        public var question: String

        /// A soulution to the task (May be changed to support multiple solutions)
        public var solution: String?

        /// The semester of the exam
        public var examPaperSemester: ExamSemester?

        /// The year of the exam
        public var examPaperYear: Int?

        /// The id of the new edited task if there exists one
        public var editedTaskID: Task.ID?
    }
}
