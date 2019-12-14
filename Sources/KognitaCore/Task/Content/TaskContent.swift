//
//  TaskContent.swift
//  KognitaCore
//
//  Created by Mats Mollestad on 10/04/2019.
//

public struct TaskContent {

    public let task: Task
    public let topic: Topic
    public let subject: Subject
    public let creator: User?

    /// The path of the task
    public let taskTypePath: String
}

public struct CreatorTaskContent {
    public let task: Task
    public let topic: Topic
    public let creator: User
    public let IsMultipleChoise: Bool
    
    public var taskTypePath: String {
        if IsMultipleChoise {
            return "tasks/multiple-choise"
        } else {
            return "tasks/flash-card"
        }
    }
}
