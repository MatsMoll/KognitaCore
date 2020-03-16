//
//  MultipleChoiseTaskSubmit.swift
//  App
//
//  Created by Mats Mollestad on 27/01/2019.
//

import Vapor


extension MultipleChoiseTask {
    
    /// The content needed to submit a answer to a `MultipleChoiseTask`
    public struct Submit: Content, TaskSubmitable {

        /// The time used to answer the question
        public let timeUsed: TimeInterval?

        /// The choise id's
        public let choises: [MultipleChoiseTaskChoise.ID]

        public internal(set) var taskIndex: Int
    }
}

extension MultipleChoiseTaskChoise {
    public struct Result: Content {
        public let id: MultipleChoiseTaskChoise.ID
        public let isCorrect: Bool
    }
}
