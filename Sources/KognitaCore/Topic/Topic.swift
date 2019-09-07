//
//  Topic.swift
//  App
//
//  Created by Mats Mollestad on 07/10/2018.
//

import FluentPostgreSQL
import Vapor

public final class Topic : KognitaCRUDModel, KognitaModelUpdatable {
    
    public struct Response : Content {
        public let topic: Topic
        public let subtopics: [Subtopic]
    }
    
    public var id: Int?

    /// The subject the topic is assigned to
    public var subjectId: Subject.ID

    /// The name of the topic
    public private(set) var name: String

    /// A description of the topic
    public private(set) var description: String

    /// The chapther number in a subject
    public private(set) var chapter: Int

    /// The id of the creator
    public internal(set) var creatorId: User.ID
    
    public var createdAt: Date?
    public var updatedAt: Date?
    
    
    public init(name: String, description: String, chapter: Int, subjectId: Subject.ID, creatorId: User.ID) throws {
        self.name           = name
        self.description    = description
        self.chapter        = chapter
        self.subjectId      = subjectId
        self.creatorId      = creatorId

        try validateTopic()
    }

    init(content: Create.Data, subject: Subject, creator: User) throws {
        creatorId   = try creator.requireID()
        subjectId   = try subject.requireID()
        name        = content.name
        description = content.description
        chapter     = content.chapter

        try validateTopic()
    }

    private func validateTopic() throws {
        guard try name.validateWith(regex: "[\\u0028-\\u003B\\u0041-\\u005A\\u0061-\\u007A\\u00B4-\\u00FF\\- ]*") else {
            throw Abort(.badRequest, reason: "Misformed name")
        }
        description.makeHTMLSafe()
    }

    public func updateValues(with content: Create.Data) throws {
        name        = content.name
        description = content.description
        chapter     = content.chapter

        try validateTopic()
    }
    
    
    public static func addTableConstraints(to builder: SchemaCreator<Topic>) {
        
        builder.unique(on: \.chapter, \.subjectId)

        builder.reference(from: \.subjectId, to: \Subject.id, onUpdate: .cascade, onDelete: .cascade)
        builder.reference(from: \.creatorId, to: \User.id, onUpdate: .cascade, onDelete: .setNull)
    }
}

extension Topic {
    
    public struct Create : KognitaRequestData {
        
        public struct Data : Content {
            
            /// This subject id
            public let subjectId: Subject.ID

            /// The name of the topic
            public let name: String

            /// A description of the topic
            public let description: String

            /// The chapther number in a subject
            public let chapter: Int
        }
        
        public typealias Response = Topic
    }
    
    public typealias Edit = Create
}

extension Topic {

    var subject: Parent<Topic, Subject> {
        return parent(\.subjectId)
    }

    var creator: Parent<Topic, User> {
        return parent(\.creatorId)
    }

    func numberOfTasks(_ conn: DatabaseConnectable) throws -> Future<Int> {
        return try Repository.shared
            .numberOfTasks(in: self, on: conn)
    }

    func tasks(on conn: DatabaseConnectable) throws -> Future<[Task]> {
        return try Repository.shared
            .tasks(in: self, on: conn)
    }

    func subtopics(on conn: DatabaseConnectable) throws -> Future<[Subtopic]> {
        return try Repository.shared
            .subtopics(in: self, on: conn)
    }

    func content(on conn: DatabaseConnectable) throws -> Future<Topic.Response> {
        return try Repository.shared
            .content(for: self, on: conn)
    }
}

extension Topic: Content { }
extension Topic: Parameter { }


extension Subtopic {
    public static let unselected = Subtopic(name: "", chapter: 0, topicId: 0)
}

extension Topic {
    public static let unselected = try! Topic(name: "Velg ...", description: "", chapter: 0, subjectId: 0, creatorId: 0)
}

extension Topic.Response {
    public static let unselected: Topic.Response = Topic.Response(topic: .unselected, subtopics: [.unselected])
}
