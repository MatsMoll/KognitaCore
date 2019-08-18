//
//  TaskResultContent.swift
//  KognitaCore
//
//  Created by Mats Mollestad on 12/04/2019.
//

import Vapor


public struct TopicResultContent: Content {
    public let results: [TaskResult]
    public let topic: Topic
    public let subject: Subject
    public let revisitDate: Date
    public var daysUntilRevisit: Int

    init(results: [TaskResult], topic: Topic, subject: Subject) {
        self.results = results
        self.topic = topic
        self.subject = subject
        self.revisitDate = results.first?.revisitDate ?? Date()
        self.daysUntilRevisit = (Calendar.current.dateComponents([.day], from: Date(), to: revisitDate).day ?? -1) + 1
    }
}

public struct TaskResultContent: Content {
    public let result: TaskResult
    public let daysUntilRevisit: Int?

    public var description: String {
        if result.resultScore < 0.2 {
            return "Det gikk ikke så bra sist, så prøv igjen"
        } else if result.resultScore < 1 {
            return "Du hadde noe peiling, kanskje det går bedre denne gangen?"
        } else {
            return "Dette gikk bra sist"
        }
    }

    /// The bootstrap color class to use based on the `daysUntilRevisit` variable
    public var revisitColorClass: String {
        switch result.resultScore {
        case ...0.3: return "badge-danger"
        case 0.2...0.8: return "badge-warning"
        default: return "badge-success"
        }
    }
}

