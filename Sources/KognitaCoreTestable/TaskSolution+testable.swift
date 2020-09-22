//
//  TaskSolution+testable.swift
//  KognitaCoreTestable
//
//  Created by Mats Mollestad on 20/10/2019.
//

import Vapor
import FluentKit
@testable import KognitaCore

extension TaskSolution {

    public static func create(creator: User?   = nil,
                              task: TaskDatabaseModel?   = nil,
                              solution: String  = UUID().uuidString,
                              presentUser: Bool    = true,
                              on app: Application) throws -> TaskSolution {

        let usedCreator = try creator ?? User.create(on: app)
        let usedTask = try task ?? TaskDatabaseModel.create(on: app)

        return try create(creatorId: usedCreator.id, solution: solution, presentUser: presentUser, taskID: usedTask.requireID(), on: app.db)
    }

    public static func create(creatorId: User.ID,
                              solution: String,
                              presentUser: Bool,
                              taskID: Task.ID,
                              on database: Database) throws -> TaskSolution {

        let solution = try TaskSolution.DatabaseModel(
            data: .init(
                solution: solution,
                presentUser: presentUser,
                taskID: taskID
            ),
            creatorID: creatorId
        )

        return try solution.save(on: database)
            .flatMapThrowing { try solution.content() }
            .wait()
    }
}
