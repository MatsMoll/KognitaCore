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

    public var creatorName: String? { return creator?.name }

    public var subjectName: String { return subject.name }

    public var subjectID: Int { return subject.id ?? 0 }

    public var topicName: String { return topic.name }

    public var topicID: Int { return topic.id ?? 0 }

    public var taskID: Int { return task.id ?? 0 }

    public var question: String { return task.question }

    public var status: String { return "" }

}
