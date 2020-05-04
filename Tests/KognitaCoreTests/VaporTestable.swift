//
//  VaporTestable.swift
//  App
//
//  Created by Mats Mollestad on 08/11/2018.
//
// swiftlint:disable force_try

import Vapor
import XCTest
import FluentPostgreSQL

/// A class that setups a application in a testable enviroment and creates a connection to the database
class VaporTestCase: XCTestCase {

    enum Errors: Error {
        case badTest
    }

    var conn: PostgreSQLConnection!

    var envArgs: [String]?

    var app: Application!

    override func setUp() {
        super.setUp()
        try! Application.reset()
        app = try! Application.testable()
        conn = try! app.newConnection(to: .psql).wait()
    }

    override func tearDown() {
        super.tearDown()
        app.shutdownGracefully { (error) in
            guard let error = error else { return }
            print("Error shutting down: \(error)")
        }
        conn.close()
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
}

extension Response {
    func has(statusCode: HTTPResponseStatus) {
        XCTAssertEqual(self.http.status, statusCode)
    }

    func has(headerName: String, with value: String? = nil) {
        XCTAssertTrue(self.http.headers.contains(name: headerName))
//        XCTAssertTrue(self.http.headers.firstValue(name: headerName) == value)
    }
}
