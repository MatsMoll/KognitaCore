//
//  FlashCardTask+testable.swift
//  KognitaCoreTests
//
//  Created by Eskild Brobak on 28/08/2019.
//

import Vapor
import FluentKit
@testable import KognitaCore

extension FlashCardTask {

    public static func create(
        creator: User? = nil,
        subtopic: Subtopic? = nil,
        task: TaskDatabaseModel? = nil,
        on app: Application
    ) throws -> FlashCardTask {

        let usedTask = try task ?? TaskDatabaseModel.create(creator: creator, subtopic: subtopic, on: app)

        return try create(task: usedTask, on: app.db)
    }

    public static func create(task: TaskDatabaseModel, on database: Database) throws -> FlashCardTask {
        let task = try FlashCardTask(task: task)

        return try task.create(on: database)
            .transform(to: task)
            .wait()
    }
}
