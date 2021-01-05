//
//  DatabaseResourceRepository.swift
//  KognitaCore
//
//  Created by Mats Mollestad on 03/01/2021.
//

import Vapor
import FluentKit
import FluentSQL
import FluentPostgresDriver

struct DatabaseResourceRepository: ResourceRepository {

    let database: Database

    private func createResourceWith(title: String, userID: User.ID) -> EventLoopFuture<Resource.ID> {
        let resource = Resource.DatabaseModel(title: title, addedByUserID: userID)
        return resource.create(on: database)
            .flatMapThrowing {
                try resource.requireID()
            }
    }

    func create(video: VideoResource.Create.Data, by userID: User.ID) -> EventLoopFuture<Resource.ID> {
        createResourceWith(title: video.title, userID: userID)
            .flatMap { resourceID in
                VideoResource.DatabaseModel(id: resourceID, data: video)
                    .create(on: database)
                    .transform(to: resourceID)
            }
    }

    func create(book: BookResource.Create.Data, by userID: User.ID) -> EventLoopFuture<Resource.ID> {
        createResourceWith(title: book.title, userID: userID)
            .flatMap { resourceID in
                BookResource.DatabaseModel(id: resourceID, data: book)
                    .create(on: database)
                    .transform(to: resourceID)
            }
    }

    func create(article: ArticleResource.Create.Data, by userID: User.ID) -> EventLoopFuture<Resource.ID> {
        createResourceWith(title: article.title, userID: userID)
            .flatMap { resourceID in
                ArticleResource.DatabaseModel(id: resourceID, url: article.url, author: article.author)
                    .create(on: database)
                    .transform(to: resourceID)
            }
    }

    func connect(subtopicID: Subtopic.ID, to resourceID: Resource.ID) -> EventLoopFuture<Void> {
        fatalError()
    }

    func disconnect(subtopicID: Subtopic.ID, from resourceID: Resource.ID) -> EventLoopFuture<Void> {
        fatalError()
    }

    func resourcesFor(subtopicID: Subtopic.ID) -> EventLoopFuture<[Resource]> {
        fatalError()
    }

    func connect(taskID: Task.ID, to resourceID: Resource.ID) -> EventLoopFuture<Void> {
        Resource.TaskPivot.query(on: database)
            .filter(\.$resource.$id == resourceID)
            .filter(\.$task.$id == taskID)
            .first()
            .flatMap { connection in
                if connection != nil {
                    return database.eventLoop.future()
                } else {
                    return Resource.TaskPivot(resourceID: resourceID, taskID: taskID)
                        .create(on: database)
                }
            }

    }

    func disconnect(taskID: Task.ID, from resourceID: Resource.ID) -> EventLoopFuture<Void> {
        Resource.TaskPivot.query(on: database)
            .filter(\.$resource.$id == resourceID)
            .filter(\.$task.$id == taskID)
            .first()
            .flatMap { connection in
                guard let connection = connection else { return database.eventLoop.future() }
                return connection.delete(on: database)
            }
    }

    func resourcesFor(taskID: Task.ID) -> EventLoopFuture<[Resource]> {
        Resource.TaskPivot.query(on: database)
            .filter(\.$task.$id == taskID)
            .all(\.$resource.$id)
            .flatMap(resourcesWith(ids: ))
    }

    private func resourcesWith(ids: [Resource.ID]) -> EventLoopFuture<[Resource]> {

        Resource.DatabaseModel.query(on: database)
            .filter(\.$id ~~ ids)
            .all()
            .flatMap { resources in

                let titles = Dictionary(uniqueKeysWithValues: resources.compactMap { try? ($0.requireID(), $0.title) })

                return VideoResource.DatabaseModel.query(on: database)
                    .filter(\.$id ~~ ids)
                    .all()
                    .flatMap { videoResources in

                        BookResource.DatabaseModel.query(on: database)
                            .filter(\.$id ~~ ids)
                            .all()
                            .flatMap { bookResources in

                                ArticleResource.DatabaseModel.query(on: database)
                                    .filter(\.$id ~~ ids)
                                    .all()
                                    .map { articleResources -> [Resource] in
                                        combineResources(
                                            videos: videoResources,
                                            books: bookResources,
                                            articles: articleResources,
                                            titles: titles
                                        )
                                    }
                            }
                    }
            }
    }

    private func combineResources(videos: [VideoResource.DatabaseModel], books: [BookResource.DatabaseModel], articles: [ArticleResource.DatabaseModel], titles: [Resource.ID: String]) -> [Resource] {

        videos.compactMap { video in
            guard let title = (try? titles[video.requireID()]) else { return nil }
            return Resource.video(
                VideoResource(
                    url: video.url,
                    title: title,
                    creator: video.creator,
                    duration: video.duration
                )
            )
        } +
        books.compactMap { book in
            guard let title = (try? titles[book.requireID()]) else { return nil }
            return Resource.book(
                BookResource(
                    title: title,
                    bookTitle: book.bookTitle,
                    startPageNumber: book.startPageNumber,
                    endPageNumber: book.endPageNumber,
                    author: book.author
                )
            )
        } +
        articles.compactMap { article in
            guard let title = (try? titles[article.requireID()]) else { return nil }
            return Resource.article(
                ArticleResource(
                    title: title,
                    url: article.url,
                    author: article.author
                )
            )
        }
    }

    func deleteResourceWith(id: Resource.ID) -> EventLoopFuture<Void> {
        Resource.DatabaseModel.find(id, on: database)
            .unwrap(or: Abort(.badRequest))
            .delete(on: database)
    }
}
