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
    var isDraft: Bool { get }

    /// The semester of the exam
    var examID: Exam.ID? { get }
    
    /// The resources assosiated with a task
    var resources: [Resource.Create] { get }
}

extension TaskCreationContentable where Self: Validatable {

    public static func basicValidations(_ validations: inout Validations) {
        validations.add("question", as: String.self, is: !.empty)
        validations.add("examPaperYear", as: Int?.self, is: .nil || .range(1990...))
    }

    public static func validations(_ validations: inout Validations) {
        basicValidations(&validations)
    }
}

extension MultipleChoiceTask.Create.Data: TaskCreationContentable {
    public var isDraft: Bool { false }
}
