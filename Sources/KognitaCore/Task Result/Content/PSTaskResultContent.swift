//
//  PSTaskResultContent.swift
//  KognitaCore
//
//  Created by Mats Mollestad on 10/04/2019.
//

import Foundation

public protocol TaskResultable {
    var topicID: Topic.ID { get }
    var topicName: String { get }
    var taskIndex: Int { get }
    var question: String { get }
    var revisitTime: Int { get }
    var resultDescription: String { get }
    var resultScore: Double { get }
    var timeUsed: TimeInterval { get }
    var date: Date? { get }
    var revisitDate: Date? { get }
}

extension PracticeSession {
    public struct TaskResult: Codable, TaskResultable {

        public var topicID: Topic.ID

        public var topicName: String

        public var taskIndex: Int

        public var question: String
        
        public var revisitTime: Int { 0 }

        public var resultDescription: String { "" }

        public var score: Double

        public var resultScore: Double { score * 100 }

        public var timeUsed: TimeInterval

        public var date: Date?

        public var revisitDate: Date?
    }
}

public struct PSTaskResult: TaskResultable {
    public var topicID: Topic.ID { topic.id ?? 0 }

    public let task: Task
    public let topic: Topic
    public let result: TaskResult
    public let taskIndex: Int

    public var topicName: String { return topic.name }

    public var question: String { return task.question }

    public var resultDescription: String {
        if result.resultScore.remainder(dividingBy: 1) == 0 {
            return "\(Int(result.resultScore)) poeng"
        } else {
            return "\((100 * result.resultScore).rounded() / 100) poeng"
        }
    }

    public var resultScore: Double {
        return result.resultScore * 100
    }

    public var timeUsed: TimeInterval { return 0 }

    public var date: Date? { return nil }

    public var revisitTime: Int {
        return ScoreEvaluater.shared
            .daysUntillReview(score: result.resultScore)
    }

    public var revisitDate: Date? {
        return result.revisitDate
    }
}
