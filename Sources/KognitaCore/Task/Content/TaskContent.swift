//
//  TaskContent.swift
//  KognitaCore
//
//  Created by Mats Mollestad on 10/04/2019.
//

public struct TaskContent {

//    let task: TaskDatabaseModel
    public let topic: Topic
    public let subject: Subject
    public let creator: User?

    /// The path of the task
    public let taskTypePath: String
}
//
public struct CreatorTaskContent {
//    let task: TaskDatabaseModel
    public let topic: Topic
    public let creator: User
    public let isMultipleChoise: Bool

    public var taskTypePath: String {
        if isMultipleChoise {
            return "tasks/multiple-choise"
        } else {
            return "tasks/flash-card"
        }
    }
}
