//
//  PSTaskResultContent.swift
//  KognitaCore
//
//  Created by Mats Mollestad on 10/04/2019.
//

import Foundation

public struct PSTaskResult {

    public let task: Task
    public let topic: Topic
    public let result: TaskResult

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

    public var timeUsed: String { return "Ukjent" }

    public var date: Date? { return nil }

    public var revisitTime: Int {
        return ScoreEvaluater.shared
            .daysUntillReview(score: result.resultScore)
    }

    public var revisitDate: Date? {
        return result.revisitDate
    }
}
