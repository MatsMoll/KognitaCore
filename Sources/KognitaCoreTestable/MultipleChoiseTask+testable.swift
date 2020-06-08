//
//  MultipleChoiseTask+testable.swift
//  AppTests
//
//  Created by Mats Mollestad on 10/11/2018.
//

import Vapor
import FluentPostgreSQL
import XCTest
@testable import KognitaCore

extension MultipleChoiceTask {

    public static func create(
        creator: User?       = nil,
        subtopic: Subtopic?   = nil,
        task: Task?       = nil,
        isMultipleSelect: Bool        = true,
        choises: [MultipleChoiceTaskChoice.Create.Data] = MultipleChoiceTaskChoice.Create.Data.standard,
        isTestable: Bool        = false,
        on conn: PostgreSQLConnection
    ) throws -> MultipleChoiceTask {

        let usedTask = try task ?? Task.create(creator: creator, subtopic: subtopic, isTestable: isTestable, on: conn)

        return try create(taskId: usedTask.requireID(),
                          isMultipleSelect: isMultipleSelect,
                          choises: choises,
                          on: conn)
    }

    public static func create(
        taskId: Task.ID,
        isMultipleSelect: Bool        = true,
        choises: [MultipleChoiceTaskChoice.Create.Data] = MultipleChoiceTaskChoice.Create.Data.standard,
        on conn: PostgreSQLConnection
    ) throws -> MultipleChoiceTask {

        return try MultipleChoiceTask.DatabaseModel(isMultipleSelect: isMultipleSelect, taskID: taskId)
            .create(on: conn)
            .flatMap { task in
                try choises.map {
                    try MultipleChoiseTaskChoise(content: $0, taskID: task.requireID())
                        .create(on: conn)
                }
                .flatten(on: conn)
                .transform(to: task)
        }
        .flatMap { try $0.content(on: conn) }
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
