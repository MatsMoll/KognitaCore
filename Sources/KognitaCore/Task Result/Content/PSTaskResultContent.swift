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
    var isSetManually: Bool { get }
}
