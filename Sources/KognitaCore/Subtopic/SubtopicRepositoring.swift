//
//  SubtopicRepository.swift
//  KognitaCore
//
//  Created by Mats Mollestad on 26/08/2019.
//

import Vapor
import FluentPostgreSQL

public protocol SubtopicRepositoring: DeleteModelRepository {
    func create(from content: Subtopic.Create.Data, by user: User?) throws -> EventLoopFuture<Subtopic.Create.Response>
    func updateModelWith(id: Int, to data: Subtopic.Update.Data, by user: User) throws -> EventLoopFuture<Subtopic.Update.Response>
    func find(_ id: Subtopic.ID) -> EventLoopFuture<Subtopic?>
    func find(_ id: Subtopic.ID, or error: Error) -> EventLoopFuture<Subtopic>
    func getSubtopics(in topic: Topic) throws -> EventLoopFuture<[Subtopic]>
    func subtopics(with topicID: Topic.ID) -> EventLoopFuture<[Subtopic]>
}
