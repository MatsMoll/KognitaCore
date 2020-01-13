//
//  MultipleChoiseTaskContent.swift
//  KognitaCore
//
//  Created by Mats Mollestad on 10/04/2019.
//

import Vapor

extension MultipleChoiseTask {
    
    public struct Data: Content {

        public let task: Task

        public let choises: [MultipleChoiseTaskChoise]

        public let isMultipleSelect: Bool

        init(task: Task, multipleTask: MultipleChoiseTask, choises: [MultipleChoiseTaskChoise]) {
            self.task               = task
            self.isMultipleSelect   = multipleTask.isMultipleSelect
            self.choises            = choises
        }

        var betaFormatted: BetaFormat {
            BetaFormat(
                task: task.betaFormatted,
                choises: choises,
                isMultipleSelect: isMultipleSelect
            )
        }
    }
    
    public struct Create {
        
        public struct Data: Content, TaskCreationContentable {

            public let subtopicId: Topic.ID

            public let description: String?

            public let question: String

            public let solution: String

            public let isMultipleSelect: Bool

            public let examPaperSemester: Task.ExamSemester?

            public let examPaperYear: Int?

            public let isTestable: Bool

            public let choises: [MultipleChoiseTaskChoise.Data]

            public func validate() throws {
                try (self as TaskCreationContentable).validate()
                let numberOfCorrectChoises = choises.filter { $0.isCorrect }
                guard numberOfCorrectChoises.count > 0 else {
                    throw Abort(.badRequest)
                }
                if !isMultipleSelect {
                    guard numberOfCorrectChoises.count == 1 else {
                        throw Abort(.badRequest)
                    }
                }
            }
        }
        
        public typealias Response = MultipleChoiseTask
    }
    
    public typealias Edit = Create
}

extension MultipleChoiseTaskChoise {
    public struct Data: Content {

        public let choise: String

        public let isCorrect: Bool
    }
}
