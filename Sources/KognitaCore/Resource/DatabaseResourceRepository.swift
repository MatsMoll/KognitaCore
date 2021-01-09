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
        VideoResource.DatabaseModel.query(on: database)
            .filter(\.$url == video.url)
            .first()
            .flatMap { existingResource in
                if let resourceID = existingResource?.id {
                    return database.eventLoop.future(resourceID)
                }

                return createResourceWith(title: video.title, userID: userID)
                    .flatMap { resourceID in
                        VideoResource.DatabaseModel(id: resourceID, data: video)
                            .create(on: database)
                            .transform(to: resourceID)
                    }
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
        ArticleResource.DatabaseModel.query(on: database)
            .filter(\.$url == article.url)
            .first()
            .flatMap { existingResource in
                if let resourceID = existingResource?.id {
                    return database.eventLoop.future(resourceID)
                }
                return createResourceWith(title: article.title, userID: userID)
                    .flatMap { resourceID in
                        ArticleResource.DatabaseModel(id: resourceID, url: article.url, author: article.author)
                            .create(on: database)
                            .transform(to: resourceID)
                    }
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

    func connect(termID: Term.ID, to resourceID: Resource.ID) -> EventLoopFuture<Void> {
        Resource.TermPivot.query(on: database)
            .filter(\.$resource.$id == resourceID)
            .filter(\.$term.$id == termID)
            .first()
            .flatMap { connection in
                if connection != nil {
                    return database.eventLoop.future()
                } else {
                    return Resource.TermPivot(resourceID: resourceID, termID: termID)
                        .create(on: database)
                }
            }
    }

    func disconnect(termID: Term.ID, from resourceID: Resource.ID) -> EventLoopFuture<Void> {
        Resource.TermPivot.query(on: database)
            .filter(\.$resource.$id == resourceID)
            .filter(\.$term.$id == termID)
            .first()
            .flatMap { connection in
                guard let connection = connection else { return database.eventLoop.future() }
                return connection.delete(on: database)
            }
    }

    func resourcesFor(termIDs: [Term.ID]) -> EventLoopFuture<[Resource]> {
        Resource.TermPivot.query(on: database)
            .filter(\.$term.$id ~~ termIDs)
            .all(\.$resource.$id)
            .flatMap(resourcesWith(ids: ))
    }

    func resourcesFor(taskID: Task.ID) -> EventLoopFuture<[Resource]> {
        Resource.TaskPivot.query(on: database)
            .filter(\.$task.$id == taskID)
            .all(\.$resource.$id)
            .flatMap(resourcesWith(ids: ))
    }

    func resourcesFor(taskIDs: [Task.ID]) -> EventLoopFuture<[Resource]> {
        Resource.TaskPivot.query(on: database)
            .filter(\.$task.$id ~~ taskIDs)
            .all(\.$resource.$id)
            .flatMap(resourcesWith(ids: ))
    }

    private func resourcesWith(ids: [Resource.ID]) -> EventLoopFuture<[Resource]> {

        let uniqueIDs = Set(ids)

        return Resource.DatabaseModel.query(on: database)
            .filter(\.$id ~~ uniqueIDs)
            .all()
            .flatMap { resources in

                let titles = Dictionary(uniqueKeysWithValues: resources.compactMap { try? ($0.requireID(), $0.title) })

                return VideoResource.DatabaseModel.query(on: database)
                    .filter(\.$id ~~ uniqueIDs)
                    .all()
                    .flatMap { videoResources in

                        BookResource.DatabaseModel.query(on: database)
                            .filter(\.$id ~~ uniqueIDs)
                            .all()
                            .flatMap { bookResources in

                                ArticleResource.DatabaseModel.query(on: database)
                                    .filter(\.$id ~~ uniqueIDs)
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
            guard
                let id = try? video.requireID(),
                let title = titles[id]
            else { return nil }
            return Resource.video(
                VideoResource(
                    id: id,
                    url: video.url,
                    title: title,
                    creator: video.creator,
                    duration: video.duration
                )
            )
        } +
        books.compactMap { book in
            guard
                let id = try? book.requireID(),
                let title = titles[id]
            else { return nil }
            return Resource.book(
                BookResource(
                    id: id,
                    title: title,
                    bookTitle: book.bookTitle,
                    startPageNumber: book.startPageNumber,
                    endPageNumber: book.endPageNumber,
                    author: book.author
                )
            )
        } +
        articles.compactMap { article in
            guard
                let id = try? article.requireID(),
                let title = titles[id]
            else { return nil }
            return Resource.article(
                ArticleResource(
                    id: id,
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

    public func analyseResourcesIn(subjectID: Subject.ID) -> EventLoopFuture<Void> {
        VideoResource.DatabaseModel.query(on: database)
            .all()
            .flatMap { videos in

                ArticleResource.DatabaseModel.query(on: database)
                    .all()
                    .map { articles in
                        var existingResources = [String: Resource.ID]()
                        existingResources = articles.reduce(into: existingResources) { $0[$1.url] = $1.id! }
                        return videos.reduce(into: existingResources) { $0[$1.url] = $1.id! }
                    }
            }
            .flatMap { existingResources in
                TaskSolution.DatabaseModel.query(on: database)
                    .join(parent: \TaskSolution.DatabaseModel.$task)
                    .join(parent: \TaskDatabaseModel.$subtopic)
                    .join(parent: \Subtopic.DatabaseModel.$topic)
                    .filter(Topic.DatabaseModel.self, \Topic.DatabaseModel.$subject.$id == subjectID)
                    .all()
                    .map { solutions in
                        solutions.flatMap { solution in
                            solution.solution.hrefs()
                                .map { (solution.$task.id, $0) }
                        }
                    }
                    .map { links in
                        groupResources(links: links)
                    }
                    .flatMap { solutionResources in
                        saveResources(existing: existingResources, solutions: solutionResources)
                }
            }
    }

    func groupResources(links: [(Task.ID, PageLink)]) -> ResourceAnalyse {
        var articles = [(ArticleResource.Create.Data, Set<Task.ID>)]()
        var videos = [(VideoResource.Create.Data, Set<Task.ID>)]()

        for (url, groupedLinks) in links.group(by: \.1.url) {

            let (title, _) = groupedLinks.count(equal: \.1.title.capitalized)
                .max(by: { (first, second) in
                    first.value > second.value
                })!

            var author = url
            if let url = URL(string: url) {
                guard
                    url.lastPathComponent != ".png",
                    url.lastPathComponent != ".jpg",
                    url.lastPathComponent != ".jpeg"
                else {
                    continue
                }
            }

            if
                let components = URLComponents(string: url),
                let host = components.host
            {
                author = host
            }

            if author.lowercased().contains("youtube") {
                let video = VideoResource.Create.Data(
                    title: title,
                    url: url,
                    creator: author,
                    duration: nil
                )
                videos.append((video, Set(groupedLinks.map(\.0))))
            } else {
                let article = ArticleResource.Create.Data(
                    title: title,
                    url: url,
                    author: author
                )
                articles.append((article, Set(groupedLinks.map(\.0))))
            }
        }
        return ResourceAnalyse(
            articles: articles,
            videos: videos
        )
    }

    func saveResources(existing: [String: Resource.ID], solutions: ResourceAnalyse) -> EventLoopFuture<Void> {
        solutions.articles.map { (article, taskIDs) in
            if let resourceID = existing[article.url] {
                return taskIDs.map { taskID in
                    connect(taskID: taskID, to: resourceID)
                }
                .flatten(on: database.eventLoop)
            } else {
                return create(article: article, by: 1)
                    .flatMap { resourceID in
                        taskIDs.map { taskID in
                            connect(taskID: taskID, to: resourceID)
                        }
                        .flatten(on: database.eventLoop)
                }
            }
        }
        .flatten(on: database.eventLoop)
        .flatMap {
            solutions.videos.map { (video, taskIDs) in
                if let resourceID = existing[video.url] {
                    return taskIDs.map { taskID in
                        connect(taskID: taskID, to: resourceID)
                    }
                    .flatten(on: database.eventLoop)
                } else {
                    return create(video: video, by: 1)
                        .flatMap { resourceID in
                            taskIDs.map { taskID in
                                connect(taskID: taskID, to: resourceID)
                            }
                            .flatten(on: database.eventLoop)
                    }
                }
            }
            .flatten(on: database.eventLoop)
        }
    }
}

struct ResourceAnalyse {
    let articles: [(ArticleResource.Create.Data, Set<Task.ID>)]
    let videos: [(VideoResource.Create.Data, Set<Task.ID>)]
}
