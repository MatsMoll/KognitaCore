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

extension MultipleChoiseTask {
    
    public static func create(creator:             User?       = nil,
                       subtopic:               Subtopic?      = nil,
                       task:                Task?       = nil,
                       isMultipleSelect:    Bool        = true,
                       choises:             [MultipleChoiseTaskChoise.Create.Data] = MultipleChoiseTaskChoise.Create.Data.standard,
                       on conn:             PostgreSQLConnection) throws -> MultipleChoiseTask {
        
        let usedTask = try task ?? Task.create(creator: creator, subtopic: subtopic, on: conn)
        
        return try create(taskId: usedTask.requireID(),
                          isMultipleSelect: isMultipleSelect,
                          on: conn)
    }
    
    public static func create(taskId:              Task.ID,
                       isMultipleSelect:    Bool        = true,
                       choises:             [MultipleChoiseTaskChoise.Create.Data] = MultipleChoiseTaskChoise.Create.Data.standard,
                       on conn:             PostgreSQLConnection) throws -> MultipleChoiseTask {
        
        return try MultipleChoiseTask(isMultipleSelect: isMultipleSelect, taskID: taskId)
            .create(on: conn)
            .flatMap { task in
                try choises.map {
                    try MultipleChoiseTaskChoise(content: $0, task: task)
                        .create(on: conn)
                }
                .flatten(on: conn)
                .transform(to: task)
        }
            .wait()
    }
}

extension MultipleChoiseTaskChoise.Create.Data {
    public static let standard: [MultipleChoiseTaskChoise.Create.Data] = [
        .init(choise: "not", isCorrect: false),
        .init(choise: "yes", isCorrect: true),
        .init(choise: "not again", isCorrect: false)
    ]
}
