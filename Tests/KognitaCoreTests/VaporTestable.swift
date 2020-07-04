//
//  VaporTestable.swift
//  App
//
//  Created by Mats Mollestad on 08/11/2018.
//
// swiftlint:disable force_try

@_exported import FluentKit
@_exported import XCTVapor

import FluentSQL
import Vapor
import XCTest
import KognitaCoreTestable
@testable import KognitaCore

/// A class that setups a application in a testable enviroment and creates a connection to the database
class VaporTestCase: XCTestCase {

    enum Errors: Error {
        case badTest
    }

    var app: Application!
    var database: Database { app.db }

//    func setup() -> Application {
//        self.app = Application.testable()
//    }

    override func setUp() {
        super.setUp()
        app = try! Application.testable()
        self.resetDB()
    }

    func resetDB() {
        guard let database = app.databases.database(logger: app.logger, on: app.eventLoopGroup.next()) as? SQLDatabase else { fatalError() }
        try! database.raw("DROP SCHEMA public CASCADE").run().wait()
        try! database.raw("CREATE SCHEMA public").run().wait()
        try! database.raw("GRANT ALL ON SCHEMA public TO public").run().wait()
        try! app.autoMigrate().wait()
    }

    override func tearDown() {
        super.tearDown()
        app?.shutdown()
        app = nil
        TestableRepositories.reset()
    }

    func failableTest(line: UInt = #line, file: StaticString = #file, test: (() throws -> Void)) {
        do {
            try test()
        } catch {
            XCTFail(error.localizedDescription, file: file, line: line)
        }
    }

    func throwsError<T: Error>(of type: T.Type, line: UInt = #line, file: StaticString = #file, test: () throws -> Void) {
        do {
            try test()
            XCTFail("Did not throw an error", file: file, line: line)
        } catch let error {
            switch error {
            case is T: return
            default: XCTFail(error.localizedDescription, file: file, line: line)
            }
        }
    }

    func throwsError<T: Error>(ofType type: T.Type, line: UInt = #line, file: StaticString = #file, test: () throws -> Void) {
        do {
            try test()
            XCTFail("Did not throw an error", file: file, line: line)
        } catch let error {
            switch error {
            case is T: return
            default: XCTFail(error.localizedDescription, file: file, line: line)
            }
        }
    }
}

extension Response {
    func has(statusCode: HTTPResponseStatus, line: UInt = #line, file: StaticString = #file) {
        XCTAssertEqual(self.status, statusCode, file: file, line: line)
    }

    func has(headerName: String, with value: String? = nil, line: UInt = #line, file: StaticString = #file) {
        XCTAssertTrue(self.headers.contains(name: headerName), file: file, line: line)
//        XCTAssertTrue(self.http.headers.firstValue(name: headerName) == value)
    }
}
