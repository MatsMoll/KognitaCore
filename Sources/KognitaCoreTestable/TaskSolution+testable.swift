//
//  TaskSolution+testable.swift
//  KognitaCoreTestable
//
//  Created by Mats Mollestad on 20/10/2019.
//

import Vapor
import FluentPostgreSQL
@testable import KognitaCore

extension TaskSolution {

    public static func create(creator: User?   = nil,
                              task: Task?   = nil,
                              solution: String  = UUID().uuidString,
                              presentUser: Bool    = true,
                              on conn: PostgreSQLConnection) throws -> TaskSolution {

        let usedCreator = try creator ?? User.create(on: conn)
        let usedTask = try task ?? Task.create(on: conn)

        return try create(creatorId: usedCreator.id, solution: solution, presentUser: presentUser, taskID: usedTask.requireID(), on: conn)
    }

    public static func create(creatorId: User.ID,
                              solution: String,
                              presentUser: Bool,
                              taskID: Task.ID,
                              on conn: PostgreSQLConnection) throws -> TaskSolution {

        return try TaskSolution(
            data: .init(
                solution: solution,
                presentUser: presentUser,
                taskID: taskID
            ),
            creatorID: creatorId
        )
            .save(on: conn).wait()
    }
}
