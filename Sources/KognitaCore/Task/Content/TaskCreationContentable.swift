//
//  TaskCreationContentable.swift
//  KognitaCore
//
//  Created by Mats Mollestad on 10/04/2019.
//

import Vapor


public protocol TaskCreationContentable {
    var description: String? { get }
    var question: String { get }
    var solution: String? { get }
    var isExaminable: Bool { get }

    /// The semester of the exam
    var examPaperSemester: Task.ExamSemester? { get }

    /// The year of the exam
    var examPaperYear: Int? { get }

    mutating func validate() throws
}

extension TaskCreationContentable {

    public func validate() throws {
        guard !question.isEmpty else {
            throw Abort(.badRequest)
        }

        if let examYear = examPaperYear {
            let year = Calendar.current.component(.year, from: Date())
            guard examYear <= year, year > 1990 else {
                throw Abort(.badRequest)
            }
            guard examPaperSemester != nil else {
                throw Abort(.badRequest)
            }
        }
    }
}
