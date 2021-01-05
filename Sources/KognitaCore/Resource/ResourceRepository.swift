//
//  ResourceRepository.swift
//  KognitaCore
//
//  Created by Mats Mollestad on 03/01/2021.
//

import Vapor

public protocol ResourceRepository {
    func create(video: VideoResource.Create.Data, by userID: User.ID) -> EventLoopFuture<Resource.ID>
    func create(book: BookResource.Create.Data, by userID: User.ID) -> EventLoopFuture<Resource.ID>
    func create(article: ArticleResource.Create.Data, by userID: User.ID) -> EventLoopFuture<Resource.ID>

    func connect(subtopicID: Subtopic.ID, to resourceID: Resource.ID) -> EventLoopFuture<Void>
    func disconnect(subtopicID: Subtopic.ID, from resourceID: Resource.ID) -> EventLoopFuture<Void>
    func resourcesFor(subtopicID: Subtopic.ID) -> EventLoopFuture<[Resource]>

    func connect(taskID: Task.ID, to resourceID: Resource.ID) -> EventLoopFuture<Void>
    func disconnect(taskID: Task.ID, from resourceID: Resource.ID) -> EventLoopFuture<Void>
    func resourcesFor(taskID: Task.ID) -> EventLoopFuture<[Resource]>

    func deleteResourceWith(id: Resource.ID) -> EventLoopFuture<Void>
}
