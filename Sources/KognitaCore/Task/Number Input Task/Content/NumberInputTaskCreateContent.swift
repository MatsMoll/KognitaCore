//
//  NumberInputTaskCreateContent.swift
//  KognitaCore
//
//  Created by Mats Mollestad on 10/04/2019.
//

import Vapor

public struct NumberInputTaskCreateContent: Content, TaskCreationContentable {

    public let topicId: Topic.ID

    public let description: String?

    public let question: String

    public let solution: String?

    public let examPaper: String?

    public let examPaperYear: Int?

    public let examPaperSemester: Task.ExamSemester?

    public let isExaminable: Bool

    public let correctAnswer: Double

    public let unit: String?
}
