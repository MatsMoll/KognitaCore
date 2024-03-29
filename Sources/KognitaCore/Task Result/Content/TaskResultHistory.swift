//
//  TaskResultHistory.swift
//  KognitaCore
//
//  Created by Mats Mollestad on 15/04/2019.
//

import Vapor

extension TaskResult {
    public struct History: Content {

        public let numberOfTasksCompleted: Int

        public let year: Double

        public let week: Double
    }
}

public struct UserResultOverview: Content {

    let username: String

    let userID: User.ID

    let resultCount: Int

    let totalScore: Double
}
