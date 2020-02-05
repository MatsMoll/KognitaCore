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
        public let topic: Topic.Overview
        public let subtopics: [Subtopic.Overview]
    }

    public struct Overview: Content {
        public let id: Int
        public let subjectID: Subject.ID
        public let name: String
        public let chapter: Int

        init(topic: Topic) {
            self.id = topic.id ?? 0
            self.subjectID = topic.subjectId
            self.name = topic.name
            self.chapter = topic.chapter
        }
    }
    
    public var id: Int?

    /// The subject the topic is assigned to
    public var subjectId: Subject.ID

    /// The name of the topic
    public private(set) var name: String

    /// The chapther number in a subject
    public private(set) var chapter: Int
    
    public var createdAt: Date?
    public var updatedAt: Date?
    
    
    public init(name: String, chapter: Int, subjectId: Subject.ID) throws {
        self.name           = name
        self.chapter        = chapter
        self.subjectId      = subjectId

        try validateTopic()
    }

    init(content: Create.Data, subject: Subject, creator: User) throws {
        subjectId   = try subject.requireID()
        name        = content.name
        chapter     = content.chapter

        try validateTopic()
    }

    private func validateTopic() throws {
        guard try name.validateWith(regex: "[\\u0028-\\u003B\\u0041-\\u005A\\u0061-\\u007A\\u00B4-\\u00FF\\- ]*") else {
            throw Abort(.badRequest, reason: "Misformed name")
        }
    }

    public func updateValues(with content: Create.Data) throws {
        name        = content.name
        chapter     = content.chapter
        try validateTopic()
    }
    
    
    public static func addTableConstraints(to builder: SchemaCreator<Topic>) {
        
        builder.unique(on: \.chapter, \.subjectId)

        builder.reference(from: \.subjectId, to: \Subject.id, onUpdate: .cascade, onDelete: .cascade)
    }
}

extension Topic {
    
    public enum Create {
        
        public struct Data : Content {
            
            /// This subject id
            public let subjectId: Subject.ID

            /// The name of the topic
            public let name: String

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

    func numberOfTasks(_ conn: DatabaseConnectable) throws -> Future<Int> {
        return try DatabaseRepository
            .numberOfTasks(in: self, on: conn)
    }

    func tasks(on conn: DatabaseConnectable) throws -> Future<[Task]> {
        return try DatabaseRepository
            .tasks(in: self, on: conn)
    }

    func subtopics(on conn: DatabaseConnectable) throws -> Future<[Subtopic]> {
        return try DatabaseRepository
            .subtopics(in: self, on: conn)
    }

    func content(on conn: DatabaseConnectable) throws -> Future<Topic.Response> {
        return try DatabaseRepository
            .content(for: self, on: conn)
    }
}

extension Topic: Content { }
extension Topic: ModelParameterRepresentable { }
