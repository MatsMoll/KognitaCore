//
//  ExamRepository.swift
//  KognitaCore
//
//  Created by Mats Mollestad on 05/11/2020.
//

import KognitaModels
import Vapor

/// The functionality for a repository handeling exams
public protocol ExamRepository {
    /// Finds an Exam
    /// - Parameter id: The id of the exam
    func find(id: Exam.ID) -> EventLoopFuture<Exam>

    /// Fines an exam if it exists within a subject, year and type
    /// - Parameters:
    ///   - subjectID: The subject id
    ///   - year: The year of an exam
    ///   - type: The type of exam
    func findExamWith(subjectID: Subject.ID, year: Int, type: ExamType) -> EventLoopFuture<Exam?>

    /// Creates an exam
    /// - Parameter content: The data defining the exam
    func create(from content: Exam.Create.Data) -> EventLoopFuture<Exam>

    /// Updates an exam
    /// - Parameters:
    ///   - id: The id of the exam to update
    ///   - content: The content to update the exam to
    func update(id: Exam.ID, to content: Exam.Create.Data) -> EventLoopFuture<Exam>

    /// Delete an exam
    /// - Parameter id: The exam to delete
    func delete(id: Exam.ID) -> EventLoopFuture<Void>

    /// Returns all exams with in a subject
    /// - Parameter subjectID: The subject id
    func allExamsWith(subjectID: Subject.ID) -> EventLoopFuture<[Exam]>

    /// Returns all the exams in a subject, but also with the number of tasks the exam contains
    /// - Parameters:
    ///   - subjectID: The subject id
    ///   - userID: The id of the user that requests the information
    func allExamsWithNumberOfTasksFor(subjectID: Subject.ID, userID: User.ID?) -> EventLoopFuture<[Exam.WithCompletion]>
}
