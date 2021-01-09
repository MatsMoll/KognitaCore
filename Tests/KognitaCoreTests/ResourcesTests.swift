//
//  ResourcesTests.swift
//  KognitaCoreTests
//
//  Created by Mats Mollestad on 04/01/2021.
//

import XCTest
@testable import KognitaCore
import KognitaCoreTestable

final class ResourcesTests: VaporTestCase {

    var bookResource: BookResource.Create.Data {
        BookResource.Create.Data(
            title: "Intelligent Agents",
            bookTitle: "Artificial Intelligence A Modern Approach, Third Edition",
            startPageNumber: 33,
            endPageNumber: 43,
            author: "Stuart J. Russell and Peter Norvig"
        )
    }

    var videoResource: VideoResource.Create.Data {
        VideoResource.Create.Data(
            title: "Intelligent Agents",
            url: "https://www.youtube.com/watch?v=spUNpyF58BY",
            creator: "3Blue1Brown",
            duration: 90
        )
    }

    var articleResource: ArticleResource.Create.Data {
        ArticleResource.Create.Data(
            title: "Intelligent Agents",
            url: "https://www.wikipendium.no/TDT4305_Big_Data_Architecture",
            author: "Wikipendium"
        )
    }

    lazy var resourceRepository: ResourceRepository = { TestableRepositories.testable(with: app).resourceRepository }()

    func testCreateBookResources() throws {
        let user = try User.create(on: app)
        let task = try MultipleChoiceTask.create(on: app)
        let resourceID = try resourceRepository.create(book: bookResource, by: user.id).wait()
        try resourceRepository.connect(taskID: task.id, to: resourceID).wait()
        let resources = try resourceRepository.resourcesFor(taskID: task.id).wait()
        XCTAssertEqual(resources.count, 1)
        let firstResource = try XCTUnwrap(resources.first)
        XCTAssertEqual(firstResource, .book(bookResource.resource(id: firstResource.id)))
        try resourceRepository.deleteResourceWith(id: resourceID).wait()
        let updatedResources = try resourceRepository.resourcesFor(taskID: task.id).wait()
        XCTAssertTrue(updatedResources.isEmpty)
    }

    func testCreateVideoResources() throws {
        let user = try User.create(on: app)
        let task = try MultipleChoiceTask.create(on: app)
        let resource = videoResource
        let resourceID = try resourceRepository.create(video: resource, by: user.id).wait()
        try resourceRepository.connect(taskID: task.id, to: resourceID).wait()
        let resources = try resourceRepository.resourcesFor(taskID: task.id).wait()
        XCTAssertEqual(resources.count, 1)
        let firstResource = try XCTUnwrap(resources.first)
        XCTAssertEqual(firstResource, .video(videoResource.resource(id: firstResource.id)))
        try resourceRepository.deleteResourceWith(id: resourceID).wait()
        let updatedResources = try resourceRepository.resourcesFor(taskID: task.id).wait()
        XCTAssertTrue(updatedResources.isEmpty)
    }

    func testCreateDuplicateVideoResources() throws {
        let user = try User.create(on: app)
        let resource = videoResource
        let resourceID = try resourceRepository.create(video: resource, by: user.id).wait()
        let duplicateResourceID = try resourceRepository.create(video: resource, by: user.id).wait()
        XCTAssertEqual(resourceID, duplicateResourceID)
    }

    func testCreateArticleResources() throws {
        let user = try User.create(on: app)
        let task = try MultipleChoiceTask.create(on: app)
        let resource = articleResource
        let resourceID = try resourceRepository.create(article: resource, by: user.id).wait()
        try resourceRepository.connect(taskID: task.id, to: resourceID).wait()
        let resources = try resourceRepository.resourcesFor(taskID: task.id).wait()
        XCTAssertEqual(resources.count, 1)
        let firstResource = try XCTUnwrap(resources.first)
        XCTAssertEqual(firstResource, .article(articleResource.resource(id: firstResource.id)))
        try resourceRepository.deleteResourceWith(id: resourceID).wait()
        let updatedResources = try resourceRepository.resourcesFor(taskID: task.id).wait()
        XCTAssertTrue(updatedResources.isEmpty)
    }

    func testCreateDuplicateArticleResources() throws {
        let user = try User.create(on: app)
        let resource = articleResource
        let resourceID = try resourceRepository.create(article: resource, by: user.id).wait()
        let duplicateResourceID = try resourceRepository.create(article: resource, by: user.id).wait()
        XCTAssertEqual(resourceID, duplicateResourceID)
    }

    func testCreateMultipleResourcesForATask() throws {

        let user = try User.create(on: app)
        let task = try MultipleChoiceTask.create(on: app)
        let otherTask = try FlashCardTask.create(on: app)

        let bookResourceID = try resourceRepository.create(book: bookResource, by: user.id).wait()
        let videoResourceID = try resourceRepository.create(video: videoResource, by: user.id).wait()
        let articleResourceID = try resourceRepository.create(article: articleResource, by: user.id).wait()

        try resourceRepository.connect(taskID: task.id, to: bookResourceID).wait()
        try resourceRepository.connect(taskID: task.id, to: videoResourceID).wait()
        try resourceRepository.connect(taskID: task.id, to: articleResourceID).wait()
        try resourceRepository.connect(taskID: otherTask.id!, to: articleResourceID).wait()

        let resources = try resourceRepository.resourcesFor(taskID: task.id).wait()

        XCTAssertEqual(resources.count, 3)
        XCTAssertTrue(resources.contains(.book(bookResource.resource(id: bookResourceID))))
        XCTAssertTrue(resources.contains(.video(videoResource.resource(id: videoResourceID))))
        XCTAssertTrue(resources.contains(.article(articleResource.resource(id: articleResourceID))))

        try resourceRepository.deleteResourceWith(id: bookResourceID).wait()
        let updatedResources = try resourceRepository.resourcesFor(taskID: task.id).wait()

        XCTAssertEqual(updatedResources.count, 2)
        XCTAssertFalse(updatedResources.contains(.book(bookResource.resource(id: bookResourceID))))
        XCTAssertTrue(updatedResources.contains(.video(videoResource.resource(id: videoResourceID))))
        XCTAssertTrue(updatedResources.contains(.article(articleResource.resource(id: articleResourceID))))
    }

    func testHrefStringDetector() throws {
        let solution =
        """
        $$\\vec{D_u} = [0, 1, 0, 0.5, 0.5]$$
        $$\\vec{q_m} = [1, -1, 1, 1, 0] \\Rightarrow [1, 0, 1, 1, 0]$$
        $$q_m = \\text{"American Former President"}$$
        Les mer på [Rochio Update Method](https://en.wikipedia.org/wiki/Rocchio_algorithm)

        Les mer om [språkmodellen](https://en.wikipedia.org/wiki/Language_model)
        """

        let links = solution.hrefs()
        XCTAssertEqual(links.count, 2)
        let first = try XCTUnwrap(links.first)
        XCTAssertEqual(first.title, "Rochio Update Method")
        XCTAssertEqual(first.url, "https://en.wikipedia.org/wiki/Rocchio_algorithm")
        let last = try XCTUnwrap(links.last)
        XCTAssertEqual(last.title, "språkmodellen")
        XCTAssertEqual(last.url, "https://en.wikipedia.org/wiki/Language_model")
    }

}

extension BookResource.Create.Data {
    func resource(id: Resource.ID) -> BookResource {
        BookResource(
            id: id,
            title: title,
            bookTitle: bookTitle,
            startPageNumber: startPageNumber,
            endPageNumber: endPageNumber,
            author: author
        )
    }
}

extension VideoResource.Create.Data {
    func resource(id: Resource.ID) -> VideoResource {
        VideoResource(
            id: id,
            url: url,
            title: title,
            creator: creator,
            duration: duration
        )
    }
}
extension ArticleResource.Create.Data {
    func resource(id: Resource.ID) -> ArticleResource {
        ArticleResource(
            id: id,
            title: title,
            url: url,
            author: author
        )
    }
}
