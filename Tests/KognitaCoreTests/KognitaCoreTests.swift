//
//  KognitaCoreTests.swift
//  KognitaCoreTests
//
//  Created by Mats Mollestad on 18/08/2019.
//
import XCTest

#if !canImport(ObjectiveC)
public func allTests() -> [XCTestCaseEntry] {
    return [
        testCase(TaskResultRepoTests.allTests),
        testCase(TaskTests.allTests),
        testCase(TopicTests.allTests),
        testCase(MultipleChoiseTaskTests.allTests),
        testCase(UserTests.allTests),
        testCase(PracticeSessionTests.allTests),
        testCase(SubjectTests.allTests),
//        testCase(WorkPointTests.allTests),
        testCase(FlashCardTaskTests.allTests),
        testCase(SubjectTestTests.allTests),
    ]
}
#endif

