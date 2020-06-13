//
//  SubtopicRepository.swift
//  KognitaCore
//
//  Created by Mats Mollestad on 26/08/2019.
//

import Vapor
import FluentPostgreSQL

public protocol SubtopicRepositoring: CreateModelRepository,
    UpdateModelRepository,
    DeleteModelRepository,
    RetriveModelRepository
    where
    ID              == Int,
    Model           == Subtopic,
    CreateData      == Subtopic.Create.Data,
    CreateResponse  == Subtopic.Create.Response,
    UpdateData      == Subtopic.Update.Data,
    UpdateResponse  == Subtopic.Update.Response {
    func find(_ id: Subtopic.ID) -> EventLoopFuture<Subtopic?>
    func getSubtopics(in topic: Topic) throws -> EventLoopFuture<[Subtopic]>
    func subtopics(with topicID: Topic.ID) -> EventLoopFuture<[Subtopic]>
}
