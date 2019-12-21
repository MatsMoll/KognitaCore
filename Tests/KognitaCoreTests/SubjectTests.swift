//
//  SubjectTests.swift
//  App
//
//  Created by Mats Mollestad on 11/10/2018.
//

import Vapor
import XCTest
import FluentPostgreSQL
import Crypto
@testable import KognitaCore

class SubjectTests: VaporTestCase {

    func testExportAndImport() throws {
        
        let subject     = try Subject.create(on: conn)
        let topic       = try Topic.create(subject: subject, on: conn)
        let subtopicOne = try Subtopic.create(chapter: 1, topic: topic, on: conn)
        let subtopicTwo = try Subtopic.create(chapter: 2, topic: topic, on: conn)
        
        _ = try MultipleChoiseTask.create(subtopic: subtopicOne, on: conn)
        _ = try MultipleChoiseTask.create(subtopic: subtopicOne, on: conn)
        _ = try FlashCardTask.create(subtopic: subtopicOne, on: conn)
        
        _ = try MultipleChoiseTask.create(subtopic: subtopicTwo, on: conn)
        _ = try FlashCardTask.create(subtopic: subtopicTwo, on: conn)
        
        let subjectExport = try Topic.Repository
            .exportTopics(in: subject, on: conn).wait()
        
        XCTAssertEqual(subjectExport.subject.id, subject.id)
        XCTAssertEqual(subjectExport.topics.count, 1)
        
        guard let topicExport = subjectExport.topics.first else {
            throw Abort(.badRequest)
        }
        XCTAssertEqual(topicExport.topic.id, topic.id)
        XCTAssertEqual(topicExport.subtopics.count, 2)
        XCTAssertEqual(topicExport.subtopics.first?.multipleChoiseTasks.count, 2)
        XCTAssertEqual(topicExport.subtopics.first?.flashCards.count, 1)
        XCTAssertEqual(topicExport.subtopics.last?.multipleChoiseTasks.count, 1)
        XCTAssertEqual(topicExport.subtopics.last?.flashCards.count, 1)
        
        _ = try Subject.Repository.importContent(subjectExport, on: conn).wait()
        
        XCTAssertEqual(try Task.Repository.all(on: conn).wait().count, 10)
        XCTAssertEqual(try TaskSolution.Repository.all(on: conn).wait().count, 10)
    }

    static let allTests = [
        ("testExportAndImport", testExportAndImport)
    ]
}
