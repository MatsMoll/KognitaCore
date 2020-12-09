//
//  Exam+testable.swift
//  KognitaCoreTests
//
//  Created by Mats Mollestad on 09/12/2020.
//

import Vapor
import FluentKit
@testable import KognitaCore

extension Exam {
    public static func create(subjectID: Subject.ID, type: ExamType, year: Int, app: Application) throws -> Exam {
        let exam = Exam.DatabaseModel(content: Create.Data(subjectID: subjectID, type: type, year: year))
        try exam.create(on: app.db).wait()
        return try exam.content()
    }
}
