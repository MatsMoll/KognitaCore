//
//  NumberInputTaskCreateContent.swift
//  KognitaCore
//
//  Created by Mats Mollestad on 10/04/2019.
//

import Vapor

extension NumberInputTask {
    public struct Create : KognitaRequestData {
        
        public struct Data: Content, TaskCreationContentable {
            
            public let subtopicId: Subtopic.ID

            public let description: String?

            public let question: String

            public let solution: String?

            public let examPaperYear: Int?

            public let examPaperSemester: Task.ExamSemester?

            public let isExaminable: Bool

            public let correctAnswer: Double

            public let unit: String?
        }
        
        public typealias Response = NumberInputTask
    }
    
    public typealias Edit = Create

    public struct Data: Content {
        public let task: Task
        public let input: NumberInputTask
    }

    public struct Submit {
        public struct Data: Content, TaskSubmitable {
            public let timeUsed: TimeInterval
            public let answer: Double
        }
        
        public struct Response: Content {
            public let correctAnswer: Double
            public let wasCorrect: Bool
        }
    }
}
