//
//  Subtopic.swift
//  KognitaCore
//
//  Created by Mats Mollestad on 26/08/2019.
//

import FluentPostgreSQL
import Vapor

public final class Subtopic : KognitaCRUDModel, KognitaModelUpdatable {

    public var id: Int?

    public var name: String

    public var topicId: Topic.ID

    public var chapter: Int

    public var createdAt: Date?

    public var updatedAt: Date?


    init(name: String, chapter: Int, topicId: Topic.ID) {
        self.name = name
        self.chapter = chapter
        self.topicId = topicId
    }

    init(content: Create.Data) {
        self.name = content.name
        self.chapter = content.chapter
        self.topicId = content.topicId
    }

    public func updateValues(with content: Create.Data) {
        self.name = content.name
        self.chapter = content.chapter
        self.topicId = content.topicId
    }
    
    public static func addTableConstraints(to builder: SchemaCreator<Subtopic>) {
        builder.unique(on: \.chapter, \.topicId)
        builder.reference(from: \.topicId, to: \Topic.id, onUpdate: .cascade, onDelete: .cascade)
    }
}

extension Subtopic: Content { }
extension Subtopic: Parameter { }


extension Subtopic {

    public struct Create : KognitaRequestData {
        
        public struct Data : Content {

            public let name: String

            public var topicId: Topic.ID

            public var chapter: Int
        }
        
        public typealias Response = Subtopic
    }

    public typealias Edit = Create
}
