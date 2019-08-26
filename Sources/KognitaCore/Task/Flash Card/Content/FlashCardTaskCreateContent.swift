//
//  FlashCardTaskCreateContent.swift
//  KognitaCore
//
//  Created by Mats Mollestad on 10/04/2019.
//

import Vapor

public struct FlashCardTaskCreateContent: Content, TaskCreationContentable {

    public let subtopicId: Subtopic.ID

    public let description: String?

    public let question: String

    public let solution: String?

    public var isExaminable: Bool

    public var examPaperSemester: Task.ExamSemester?

    public var examPaperYear: Int?

    public mutating func validate() throws {
        guard !question.isEmpty else {
            throw Abort(.badRequest)
        }
        guard let solution = solution, !solution.isEmpty else {
            throw Abort(.badRequest)
        }
        examPaperYear = nil
        examPaperSemester = nil
        isExaminable = false
    }
}
