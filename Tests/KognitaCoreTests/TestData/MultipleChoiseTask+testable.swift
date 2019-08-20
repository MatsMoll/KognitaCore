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
    
    static func create(creator:             User?       = nil,
                       topic:               Topic?      = nil,
                       task:                Task?       = nil,
                       isMultipleSelect:    Bool        = true,
                       on conn:             PostgreSQLConnection) throws -> MultipleChoiseTask {
        
        let usedTask = try task ?? Task.create(creator: creator, topic: topic, on: conn)
        
        return try create(taskId: usedTask.requireID(),
                          isMultipleSelect: isMultipleSelect,
                          on: conn)
    }
    
    static func create(taskId:              Task.ID,
                       isMultipleSelect:    Bool        = true,
                       on conn:             PostgreSQLConnection) throws -> MultipleChoiseTask {
        
        return try MultipleChoiseTask(isMultipleSelect: isMultipleSelect, taskID: taskId)
            .create(on: conn).wait()
    }
}
