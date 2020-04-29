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
    Model           == Subtopic,
    CreateData      == Subtopic.Create.Data,
    CreateResponse  == Subtopic.Create.Response,
    UpdateData      == Subtopic.Edit.Data,
    UpdateResponse  == Subtopic.Edit.Response {
    static func find(_ id: Subtopic.ID, on conn: DatabaseConnectable) -> EventLoopFuture<Subtopic?>
    static func getSubtopics(in topic: Topic, with conn: DatabaseConnectable) throws -> EventLoopFuture<[Subtopic]>
}
