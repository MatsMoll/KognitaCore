//
//  ExamRepository.swift
//  KognitaCore
//
//  Created by Mats Mollestad on 05/11/2020.
//

import KognitaModels
import Vapor

public protocol ExamRepository {
    func find(id: Exam.ID) -> EventLoopFuture<Exam>
    func findExamWith(subjectID: Subject.ID, year: Int, type: ExamType) -> EventLoopFuture<Exam?>
    func create(from content: Exam.Create.Data) -> EventLoopFuture<Exam>
    func update(id: Exam.ID, to content: Exam.Create.Data) -> EventLoopFuture<Exam>
    func delete(id: Exam.ID) -> EventLoopFuture<Void>
    func allExamsWith(subjectID: Subject.ID) -> EventLoopFuture<[Exam]>
    func allExamsWithNumberOfTasksFor(subjectID: Subject.ID, userID: User.ID) -> EventLoopFuture<[Exam.WithCompletion]>
}
