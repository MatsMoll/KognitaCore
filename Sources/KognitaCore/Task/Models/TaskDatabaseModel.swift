//
//  Task.swift
//  App
//
//  Created by Mats Mollestad on 07/10/2018.
//

import Vapor
import FluentKit

public enum TaskExamSemester: String, Codable {
    case fall
    case spring

    public var norwegianDescription: String {
        switch self {
        case .fall:     return "Høst"
        case .spring:   return "Vår"
        }
    }
}

/// The superclass of all task types
final class TaskDatabaseModel: KognitaPersistenceModel, SoftDeleatableModel {

    public static let tableName: String = "Task"

    /// The semester a exam was taken
    ///
    /// - fall: The fall
    /// - spring: The spring
    public enum ExamSemester: String, Codable {
        case fall
        case spring

        public var norwegianDescription: String {
            switch self {
            case .fall:     return "Høst"
            case .spring:   return "Vår"
            }
        }
    }

    @DBID(custom: "id")
    public var id: Int?

    /// The topic.id for the topic this task relates to
    @Parent(key: "subtopicID")
    var subtopic: Subtopic.DatabaseModel

    /// Some markdown that contains extra information about the task if needed
    @Field(key: "description")
    public var description: String?

    /// The question needed to answer the task
    @Field(key: "question")
    public var question: String

    /// The id of the user who created the task
    @Parent(key: "creatorId")
    var creator: User.DatabaseModel

    /// The semester of the exam
    @Field(key: "examPaperSemester")
    public var examPaperSemester: ExamSemester?

    /// The year of the exam
    @Field(key: "examPaperYear")
    public var examPaperYear: Int?

    /// If the task can be used for testing
    @Field(key: "isTestable")
    public var isTestable: Bool

    /// The date the task was created at
    @Timestamp(key: "createdAt", on: .create)
    public var createdAt: Date?

    /// The date the task was updated at
    /// - Note: Usually a task will be marked as isOutdated and create a new `Task` when updated
    @Timestamp(key: "updatedAt", on: .update)
    public var updatedAt: Date?

    @Timestamp(key: "deletedAt", on: .delete)
    public var deletedAt: Date?

    @Children(for: \.$task)
    var solutions: [TaskSolution.DatabaseModel]

    @Children(for: \.$task)
    var results: [TaskResult.DatabaseModel]

    init(
        subtopicID: Subtopic.ID,
        description: String?,
        question: String,
        creatorID: User.ID,
        examPaperSemester: ExamSemester? = nil,
        examPaperYear: Int? = nil,
        isTestable: Bool = false,
        id: IDValue? = nil
    ) {
        self.id             = id
        self.$subtopic.id   = subtopicID
        self.description    = description
        self.question       = question
        self.$creator.id    = creatorID
        self.isTestable     = isTestable
        self.deletedAt      = nil
        if examPaperSemester != nil, examPaperYear != nil {
            self.examPaperYear  = examPaperYear
            self.examPaperSemester = examPaperSemester
        }
    }

    init(
        content: TaskCreationContentable,
        subtopicID: Subtopic.ID,
        creator: User,
        id: IDValue? = nil
    ) throws {
        self.id             = id
        self.$subtopic.id     = subtopicID
        self.description    = try content.description?.cleanXSS(whitelist: .basicWithImages())
        self.question       = try content.question.cleanXSS(whitelist: .basicWithImages())
        self.isTestable     = content.isTestable
        self.$creator.id      = creator.id
        self.examPaperSemester = nil
        self.examPaperYear  = content.examPaperYear
        self.deletedAt  = nil
        if description?.isEmpty == true {
            self.description = nil
        }
    }

    init() {}
}

extension TaskDatabaseModel {
    func update(content: TaskCreationContentable) throws -> TaskDatabaseModel {
        self.description = try? content.description?.cleanXSS(whitelist: .basicWithImages())
        self.question = try content.question.cleanXSS(whitelist: .basicWithImages())
        self.isTestable = content.isTestable
        self.examPaperYear = content.examPaperYear
        return self
    }
}

extension TaskDatabaseModel {
    enum Migrations {}
}

extension TaskDatabaseModel.Migrations {
    struct Create: KognitaModelMigration {

        typealias Model = TaskDatabaseModel

        func build(schema: SchemaBuilder) -> SchemaBuilder {
            schema.field("creatorId", .uint, .sql(.default(1)), .references(User.DatabaseModel.schema, .id, onDelete: .setDefault, onUpdate: .cascade))
                .field("subtopicID", .uint, .required, .references(Subtopic.DatabaseModel.schema, .id, onDelete: .cascade, onUpdate: .cascade))
                .field("question", .string, .required)
                .field("description", .string)
                .field("isTestable", .bool, .required)
                .field("examPaperYear", .int)
                .field("examPaperSemester", .string)
                .field("deletedAt", .datetime)
                .defaultTimestamps()
        }
    }
}

extension TaskDatabaseModel {

    var betaFormatted: TaskBetaFormat {
        TaskBetaFormat(
            description: description,
            question: question,
            solution: nil,
            examPaperSemester: nil,
            examPaperYear: examPaperYear,
            editedTaskID: nil
        )
    }

//    func taskContent(_ req: Request) -> EventLoopFuture<TaskContent> {
//        return topic(on: req)
//            .flatMap { topic in
//                topic.subject
//                    .get(on: req)
//                    .flatMap { subject in
//                        try self.getTaskTypePath(req).map { path in
//                            TaskContent(task: self, topic: topic, subject: subject, creator: nil, taskTypePath: path)
//                        }
//                }
//        }
//    }
//
//    static func taskContent(where filter: FilterOperator<PostgreSQLDatabase, Task>, on conn: DatabaseConnectable) -> EventLoopFuture<[TaskContent]> {
//        return Task.query(on: conn)
//            .filter(filter)
//            .join(\Subtopic.id, to: \Task.subtopicID)
//            .join(\Topic.id, to: \Subtopic.topicId)
//            .join(\Subject.id, to: \Topic.subjectId)
//            .alsoDecode(Topic.self)
//            .alsoDecode(Subject.self)
//            .all()
//            .flatMap { tasks in
//                return try tasks.map { (taskTopic, subject) in
//                    try taskTopic.0.getTaskTypePath(conn).map { path in
//                        TaskContent(task: taskTopic.0, topic: taskTopic.1, subject: subject, creator: nil, taskTypePath: path)
//                    }
//                }.flatten(on: conn)
//        }
//    }

//    func getTaskTypePath(_ conn: DatabaseConnectable) throws -> EventLoopFuture<String> {
//        return try Task.Repository
//            .getTaskTypePath(for: requireID(), conn: conn)
//    }
//
//    func topic(on conn: DatabaseConnectable) -> Future<Topic> {
//        return Topic.query(on: conn)
//            .join(\Subtopic.topicId, to: \Topic.id)
//            .filter(\Subtopic.id == subtopicID)
//            .first()
//            .unwrap(or: Abort(.internalServerError))
//    }
}

extension TaskDatabaseModel: Content { }

//extension TaskDatabaseModel {
public struct TaskBetaFormat: Content {

    /// Some html that contains extra information about the task if needed
    public var description: String?

    /// The question needed to answer the task
    public var question: String

    /// A soulution to the task (May be changed to support multiple solutions)
    public var solution: String?

    /// The semester of the exam
    public var examPaperSemester: TaskExamSemester?

    /// The year of the exam
    public var examPaperYear: Int?

    /// The id of the new edited task if there exists one
    public var editedTaskID: Task.ID?
}
//}
