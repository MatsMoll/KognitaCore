//
//  Task+testable.swift
//  App
//
//  Created by Mats Mollestad on 09/11/2018.
//

import Vapor
import FluentPostgreSQL
@testable import KognitaCore

extension Task {
    
    public static func create(creator:         User?           = nil,
                       subtopic:        Subtopic?       = nil,
                       description:     String          = "Some description",
                       question:        String          = "Some question",
                       explenation:     String          = "Some explenation",
                       createSolution:  Bool            = true,
                       isTestable:      Bool            = false,
                       on conn:         PostgreSQLConnection) throws -> Task {

        let usedCreator = try creator ?? User.create(on: conn)
        let usedSubtopic = try subtopic ?? Subtopic.create(on: conn)
        
        return try create(creatorId: usedCreator.requireID(),
                          subtopicId: usedSubtopic.requireID(),
                          description: description,
                          question: question,
                          explenation: explenation,
                          createSolution: createSolution,
                          isTestable: isTestable,
                          on: conn)
    }
    
    public static func create(creatorId:       User.ID,
                       subtopicId:      Subtopic.ID,
                       description:     String          = "Some description",
                       question:        String          = "Some question",
                       explenation:     String          = "Some explenation",
                       createSolution:  Bool            = true,
                       isTestable:      Bool            = false,
                       on conn:         PostgreSQLConnection) throws -> Task {
        
        return try Task(subtopicID:     subtopicId,
                        description:    description,
                        question:       question,
                        creatorID:      creatorId,
                        isTestable:     isTestable)
            
            .save(on: conn)
            .flatMap { task in
                if createSolution {
                    return try TaskSolution(
                        data: TaskSolution.Create.Data(
                            solution: explenation,
                            presentUser: true,
                            taskID: task.requireID()),
                        creatorID: creatorId)
                        .save(on: conn)
                        .transform(to: task)
                } else {
                    return conn.future(task)
                }
        }.wait()
    }
}
