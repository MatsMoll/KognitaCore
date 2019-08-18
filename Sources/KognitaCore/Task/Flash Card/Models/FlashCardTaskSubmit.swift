//
//  FlashCardTaskSubmit.swift
//  KognitaCore
//
//  Created by Mats Mollestad on 16/04/2019.
//

import Vapor

public struct FlashCardTaskSubmit: Content, TaskSubmitable {
    public let timeUsed: TimeInterval
    public let knowledge: Double
}
