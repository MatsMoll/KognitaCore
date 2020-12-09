//
//  ExamDatabaseRepository.swift
//  KognitaCore
//
//  Created by Mats Mollestad on 05/11/2020.
//

import FluentKit
import FluentSQL
import Vapor

/// A database implementatino of a `ExamRepository`
struct ExamDatabaseRepository: ExamRepository {

    /// The database to connect to
    let database: Database

    /// The different repositories to use
    let repositories: RepositoriesRepresentable

    func find(id: Exam.ID) -> EventLoopFuture<Exam> {
        Exam.DatabaseModel.find(id, on: database)
            .unwrap(or: Abort(.badRequest))
            .content()
    }

    func findExamWith(subjectID: Subject.ID, year: Int, type: ExamType) -> EventLoopFuture<Exam?> {
        Exam.DatabaseModel.query(on: database)
            .filter(\.$subject.$id == subjectID)
            .filter(\.$year == year)
            .filter(\.$type == type)
            .first()
            .flatMapThrowing { try $0?.content() }
    }

    func create(from content: Exam.Create.Data) -> EventLoopFuture<Exam> {
        let model = Exam.DatabaseModel(content: content)
        return model.create(on: database)
            .transform(to: model)
            .content()
    }

    func update(id: Exam.ID, to content: Exam.Create.Data) -> EventLoopFuture<Exam> {
        Exam.DatabaseModel.find(id, on: database)
            .unwrap(or: Abort(.badRequest))
            .flatMap { model in
                model.update(with: content)
                return model.update(on: database)
                    .transform(to: model)
                    .content()
            }
    }

    func delete(id: Exam.ID) -> EventLoopFuture<Void> {
        Exam.DatabaseModel.find(id, on: database)
            .unwrap(or: Abort(.badRequest))
            .delete(on: database)
    }

    func allExamsWith(subjectID: Subject.ID) -> EventLoopFuture<[Exam]> {
        Exam.DatabaseModel.query(on: database)
            .filter(\.$subject.$id == subjectID)
            .all()
            .flatMapEachThrowing { model in
                try model.content()
            }
    }

    func allExamsWithNumberOfTasksFor(subjectID: Subject.ID, userID: User.ID) -> EventLoopFuture<[Exam.WithCompletion]> {
        guard let sql = database as? SQLDatabase else {
            return database.eventLoop.future(error: Abort(.internalServerError))
        }
        return sql.select()
            .count(\TaskDatabaseModel.$id, as: "numberOfTasks")
            .column(\Exam.DatabaseModel.$id)
            .column(\Exam.DatabaseModel.$year)
            .column(\Exam.DatabaseModel.$type)
            .column(\Exam.DatabaseModel.$subject.$id)
            .column(\Exam.DatabaseModel.$createdAt)
            .column(\Exam.DatabaseModel.$updatedAt)
            .from(Exam.DatabaseModel.schema)
            .join(from: \Exam.DatabaseModel.$id, to: \TaskDatabaseModel.$exam.$id)
            .where("subjectID", .equal, subjectID)
            .where("deletedAt", .is, SQLLiteral.null)
            .groupBy(\Exam.DatabaseModel.$id)
            .all(decoding: Exam.WithNumberOfTasks.self)
            .flatMap { exams in
                repositories.taskResultRepository
                    .completionInExamWith(ids: exams.map { $0.id }, userID: userID)
                    .map { completions in
                        exams.map { exam in
                            Exam.WithCompletion(
                                exam: exam,
                                completion: completions.first(where: { $0.examID == exam.id })
                            )
                        }
                    }
            }
    }
}
