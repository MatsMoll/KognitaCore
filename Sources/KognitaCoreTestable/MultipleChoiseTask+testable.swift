//
//  MultipleChoiseTask+testable.swift
//  AppTests
//
//  Created by Mats Mollestad on 10/11/2018.
//

import Vapor
import FluentKit
import XCTest
@testable import KognitaCore

extension MultipleChoiceTask {

    public static func create(
        creator: User?       = nil,
        subtopic: Subtopic?   = nil,
        task: TaskDatabaseModel?       = nil,
        isMultipleSelect: Bool        = true,
        choises: [MultipleChoiceTaskChoice.Create.Data] = MultipleChoiceTaskChoice.Create.Data.standard,
        isTestable: Bool        = false,
        exam: Exam? = nil,
        on app: Application
    ) throws -> MultipleChoiceTask {

        let usedTask = try task ?? TaskDatabaseModel.create(creator: creator, subtopic: subtopic, isTestable: isTestable, exam: exam, on: app)

        return try create(taskId: usedTask.requireID(),
                          isMultipleSelect: isMultipleSelect,
                          choises: choises,
                          on: app)
    }

    public static func create(
        taskId: Task.ID,
        isMultipleSelect: Bool        = true,
        choises: [MultipleChoiceTaskChoice.Create.Data] = MultipleChoiceTaskChoice.Create.Data.standard,
        on app: Application
    ) throws -> MultipleChoiceTask {

        let task = MultipleChoiceTask.DatabaseModel(isMultipleSelect: isMultipleSelect, taskID: taskId)

        return try task.create(on: app.db)
            .failableFlatMap {
                try choises.map {
                    try MultipleChoiseTaskChoise(content: $0, taskID: task.requireID())
                        .create(on: app.db)
                }
                .flatten(on: app.db.eventLoop)
        }
        .failableFlatMap { try TestableRepositories.testable(with: app).multipleChoiceTaskRepository.task(withID: task.requireID()) }
        .wait()
    }
}

extension MultipleChoiceTaskChoice.Create.Data {
    public static let standard: [MultipleChoiceTaskChoice.Create.Data] = [
        .init(choice: "not", isCorrect: false),
        .init(choice: "yes", isCorrect: true),
        .init(choice: "not again", isCorrect: false)
    ]
}
