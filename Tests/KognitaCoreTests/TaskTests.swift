//
//  TaskTests.swift
//  App
//
//  Created by Mats Mollestad on 09/11/2018.
//

import Vapor
import XCTest
import FluentPostgreSQL
import KognitaCore

class TaskTests: VaporTestCase {

    func testTasksInSubject() throws {

        let subject = try Subject.create(name: "test", on: conn)
        let topic = try Topic.create(subject: subject, on: conn)
        _ = try Task.create(topic: topic, on: conn)
        _ = try Task.create(topic: topic, on: conn)
        _ = try Task.create(topic: topic, on: conn)
        _ = try Task.create(topic: topic, on: conn)
        _ = try Task.create(on: conn)

        let tasks = try TaskRepository.shared
            .getTasks(in: subject, conn: conn)
            .wait()
        XCTAssertEqual(tasks.count, 4)
    }
}
