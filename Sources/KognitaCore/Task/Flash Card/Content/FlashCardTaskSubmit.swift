//
//  FlashCardTaskSubmit.swift
//  KognitaCore
//
//  Created by Mats Mollestad on 16/04/2019.
//

import Vapor

extension FlashCardTask {
    public struct Submit: Content, TaskSubmitable {
        public let timeUsed: TimeInterval?
        public let knowledge: Double
        public internal(set) var taskIndex: Int
        public let answer: String
    }
}
