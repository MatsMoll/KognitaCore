//
//  FlashCardTaskTests.swift
//  KognitaCoreTests
//
//  Created by Eskild Brobak on 28/08/2019.
//

import Vapor
import XCTest
import FluentPostgreSQL
@testable import KognitaCore

class FlashCardTaskTests: VaporTestCase {
    
    func testPracticeSessionResult() throws {
        
        let user = try User.create(on: conn)
        
        let topic = try Topic.create(on: conn)
        
        let taskOne = try FlashCardTask.create(topic: topic, on: conn)
        let taskTwo = try FlashCardTask.create(topic: topic, on: conn)
        let taskThree = try FlashCardTask.create(topic: topic, on: conn)
        let taskFour = try FlashCardTask.create(topic: topic, on: conn)
    
        let sessionContent = try PracticeSessionCreateContent(
            numberOfTaskGoal: 3,
            topicIDs: [topic.requireID()]
        )
        
        PracticeSessionRepository.shared
            .create(for: user, with: sessionContent, on: conn)
    }
}
