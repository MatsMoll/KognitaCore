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
    var isTestable: Bool { get }

    /// The semester of the exam
    var examPaperSemester: Task.ExamSemester? { get }

    /// The year of the exam
    var examPaperYear: Int? { get }
}

extension TaskCreationContentable where Self: Validatable {

    public static func basicValidations() throws -> Validations<Self> {
        var validations = Validations(Self.self)
        validations.add(\.question, at: ["question"], "No question") { (question) in
            guard question.isEmpty == false else { throw BasicValidationError("Missing question") }
        }
        validations.add(\.self, at: ["exampPaperYear"], "Invalid exam year") { data in
            let year = Calendar.current.component(.year, from: Date())
            guard let examYear = data.examPaperYear else { return }
            guard examYear <= year, year > 1990 else {
                throw BasicValidationError("Exam Year is either in the future or before 1990")
            }
            guard data.examPaperSemester != nil else {
                throw BasicValidationError("Exam semester has not been set")
            }
        }
        return validations
    }

    public static func validations() throws -> Validations<Self> { try basicValidations() }
}

extension MultipleChoiceTask.Create.Data: TaskCreationContentable {
    public var examPaperSemester: Task.ExamSemester? { nil }
}
