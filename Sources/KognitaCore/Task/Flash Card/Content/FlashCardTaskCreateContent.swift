//
//  FlashCardTaskCreateContent.swift
//  KognitaCore
//
//  Created by Mats Mollestad on 10/04/2019.
//

import Vapor

extension FlashCardTask {

    public struct Create: Content {

        public struct Data: Content, TaskCreationContentable {

            public let subtopicId: Subtopic.ID

            public let description: String?

            public let question: String

            public let solution: String

            public var isTestable: Bool

            public var examPaperSemester: Task.ExamSemester?

            public var examPaperYear: Int?
        }

        public typealias Response = Task
    }

    public typealias Edit = Create
}
