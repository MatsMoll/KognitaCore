//
//  Task+testable.swift
//  App
//
//  Created by Mats Mollestad on 09/11/2018.
//

import Vapor
import FluentKit
@testable import KognitaCore

extension TaskDatabaseModel {

    public static func create(
        creator: User?           = nil,
        subtopic: Subtopic?       = nil,
        description: String?         = nil,
        question: String          = "Some question",
        explenation: String          = "Some explenation",
        createSolution: Bool            = true,
        isTestable: Bool            = false,
        on app: Application
    ) throws -> TaskDatabaseModel {

        let usedCreator = try creator ?? User.create(on: app)
        let usedSubtopic = try subtopic ?? Subtopic.create(on: app)

        return try create(creator: usedCreator,
                          subtopicId: usedSubtopic.id,
                          description: description,
                          question: question,
                          explenation: explenation,
                          createSolution: createSolution,
                          isTestable: isTestable,
                          on: app.db)
    }

    public static func create(
        creator: User,
        subtopicId: Subtopic.ID,
        description: String?         = nil,
        question: String          = "Some question",
        explenation: String          = "Some explenation",
        createSolution: Bool            = true,
        isTestable: Bool            = false,
        on database: Database
    ) throws -> TaskDatabaseModel {

        let task = TaskDatabaseModel(subtopicID: subtopicId,
                        description: description,
                        question: question,
                        creatorID: creator.id,
                        isTestable: isTestable)

        return try task.save(on: database)
            .failableFlatMap {
                if createSolution {
                    return try TaskSolution.DatabaseRepository(database: database)
                        .create(from:
                            TaskSolution.Create.Data(
                                solution: explenation,
                                presentUser: true,
                                taskID: task.requireID()
                            ),
                            by: creator
                    )
                    .transform(to: task)
                } else {
                    return database.eventLoop.future(task)
                }
        }.wait()
    }
}
