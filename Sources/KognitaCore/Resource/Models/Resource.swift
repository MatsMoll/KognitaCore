//
//  Resource.swift
//  KognitaCore
//
//  Created by Mats Mollestad on 03/01/2021.
//

import FluentKit
import Foundation

extension Resource {
    final class DatabaseModel: Model {

        static var schema: String = "Resource"

        @DBID(custom: "id")
        var id: Int?

        @Field(key: "title")
        var title: String

        @Parent(key: "addedByUserID")
        var addedBy: User.DatabaseModel

        @Timestamp(key: "createdAt", on: .create)
        var createdAt: Date?

        @Timestamp(key: "updatedAt", on: .update)
        var updatedAt: Date?

        @Siblings(through: Resource.TaskPivot.self, from: \.$resource, to: \.$task)
        var tasks: [TaskDatabaseModel]

        init() {}

        init(title: String, addedByUserID: User.ID) {
            self.title = title
            self.$addedBy.id = addedByUserID
            self.createdAt = nil
            self.updatedAt = nil
        }
    }
}

extension Resource {
    enum Migrations {
        struct Create: Migration {

            func prepare(on database: Database) -> EventLoopFuture<Void> {
                database.schema(Resource.DatabaseModel.schema)
                    .field("id", .uint, .identifier(auto: true))
                    .field("title", .string, .required)
                    .field("addedByUserID", .uint, .required, .references(User.DatabaseModel.schema, .id, onDelete: .cascade, onUpdate: .cascade))
                    .defaultTimestamps()
                    .create()
            }

            func revert(on database: Database) -> EventLoopFuture<Void> {
                database.schema(Resource.DatabaseModel.schema)
                    .delete()
            }
        }

        struct ConvertSolutionSourceToResource: Migration {

            func prepare(on database: Database) -> EventLoopFuture<Void> {

                let repository = DatabaseResourceRepository(database: database)

                return TaskSolution.DatabaseModel.query(on: database)
                    .all()
                    .map { solutions in
                        solutions.flatMap { solution in
                            solution.solution.hrefs()
                                .map { (solution.$task.id, $0) }
                        }
                    }
                    .flatMap { links in
                        groupResources(links: links)
                            .map { (article, taskIDs) in
                                repository.create(article: article, by: 1)
                                    .flatMap { resourceID in
                                        taskIDs.map { taskID in
                                            repository.connect(taskID: taskID, to: resourceID)
                                        }
                                        .flatten(on: database.eventLoop)
                                }
                        }
                        .flatten(on: database.eventLoop)
                    }
            }

            func revert(on database: Database) -> EventLoopFuture<Void> {
                database.eventLoop.future()
            }

            func groupResources(links: [(Task.ID, PageLink)]) -> [(ArticleResource.Create.Data, [Task.ID])] {
                links.group(by: \.1.url).map { (url, groupedLinks) -> (ArticleResource.Create.Data, [Task.ID]) in

                    let (title, _) = groupedLinks.count(equal: \.1.title)
                        .max(by: { (first, second) in
                            first.value > second.value
                        })!
                    var author = "Unknown"
                    if let components = URLComponents(string: url), let host = components.host {
                        author = host
                    }

                    let article = ArticleResource.Create.Data(
                        title: title,
                        url: url,
                        author: author
                    )
                    return (article, groupedLinks.map(\.0))
                }
            }
        }
    }
}

public struct PageLink {
    public let title: String
    public let url: String
}

enum PageLinkSearchState {
    case title
    case href
    case other
}

extension String {
    public func hrefs() -> [PageLink] {
        var currentIndex = self.startIndex
        var state = PageLinkSearchState.other
        let titleStart = "["
        let hrefStart = "]("
        let hrefEnd = ")"

        var relevantIndex = self.startIndex
        var potensialTitle = ""

        var links = [PageLink]()

        while currentIndex < self.endIndex {
            switch state {
            case .other:
                guard let titleEndIndex = self.index(currentIndex, offsetBy: titleStart.count, limitedBy: self.endIndex) else {
                    currentIndex = self.endIndex
                    continue
                }
                let potensialTitleStart = String(self[currentIndex..<titleEndIndex])
                if potensialTitleStart == titleStart {
                    state = .title
                    relevantIndex = titleEndIndex
                    currentIndex = titleEndIndex
                }
            case .title:
                if self[currentIndex].isNewline {
                    state = .other
                    continue
                }
                guard let hrefStartIndex = self.index(currentIndex, offsetBy: hrefStart.count, limitedBy: self.endIndex) else {
                    currentIndex = self.endIndex
                    continue
                }
                let potensialHrefStart = String(self[currentIndex..<hrefStartIndex])
                if potensialHrefStart == hrefStart {
                    state = .href
                    potensialTitle = String(self[relevantIndex..<currentIndex])
                    relevantIndex = hrefStartIndex
                    currentIndex = hrefStartIndex
                }

            case .href:
                if self[currentIndex].isNewline {
                    state = .other
                    continue
                }
                guard let hrefEndIndex = self.index(currentIndex, offsetBy: hrefEnd.count, limitedBy: self.endIndex) else {
                    currentIndex = self.endIndex
                    continue
                }
                let potensialHrefEnd = String(self[currentIndex..<hrefEndIndex])
                if potensialHrefEnd == hrefEnd {
                    state = .other
                    let url = String(self[relevantIndex..<currentIndex])
                    links.append(
                        PageLink(
                            title: potensialTitle,
                            url: url
                        )
                    )
                    currentIndex = hrefEndIndex
                }
            }
            guard let nextIndex = self.index(currentIndex, offsetBy: 1, limitedBy: self.endIndex) else {
                currentIndex = self.endIndex
                continue
            }
            currentIndex = nextIndex
        }
        return links
    }
}
