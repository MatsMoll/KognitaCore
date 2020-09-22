//
//  LectureNoteRepository.swift
//  KognitaCore
//
//  Created by Mats Mollestad on 21/09/2020.
//

import Fluent
import Vapor

public protocol LectureNoteRepository {
    func create(from content: LectureNote.Create.Data, by user: User) throws -> EventLoopFuture<LectureNote.ID>
    func update(id: LectureNote.ID, with content: LectureNote.Create.Data, by user: User) throws -> EventLoopFuture<Void>
    func find(id: LectureNote.ID) -> EventLoopFuture<LectureNote>
}

extension LectureNote {

    struct DatabaseRepository: LectureNoteRepository {

        let database: Database
        let repositories: DatabaseRepositories

        var taskRepository: TaskRepository { repositories.taskRepository }
    }
}

extension LectureNote.DatabaseRepository {

    func create(from content: LectureNote.Create.Data, by user: User) throws -> EventLoopFuture<LectureNote.ID> {
        try self.taskRepository
            .create(
                from: TaskDatabaseModel.Create.Data(
                    content: content,
                    subtopicID: content.subtopicID,
                    solution: content.solution ?? ""
                ),
                by: user
        ).failableFlatMap { task in
            try LectureNote.DatabaseModel(id: task.requireID(), noteSession: content.noteSession)
                .create(on: self.database)
                .failableFlatMap {
                    // Endables editing as flash card task
                    try FlashCardTask(task: task).save(on: self.database)
                }
                .flatMap {
                    // Sets deletedAt in order to not use them while a note
                    task.delete(on: self.database)
            }
            .transform(to: task.id!)
        }
    }

    func update(id: LectureNote.ID, with content: LectureNote.Create.Data, by user: User) throws -> EventLoopFuture<Void> {
        LectureNote.DatabaseModel.query(on: database)
            .withDeleted()
            .join(superclass: TaskDatabaseModel.self, with: LectureNote.DatabaseModel.self)
            .join(children: \TaskDatabaseModel.$solutions)
            .filter(\.$id == id)
            .first(TaskDatabaseModel.self, TaskSolution.DatabaseModel.self)
            .unwrap(or: Abort(.badRequest))
            .flatMap { (task, solution) in
                task.question = content.question
                task.$subtopic.id = content.subtopicID

                return task.save(on: self.database)
                    .failableFlatMap {
                        try solution.update(with: TaskSolution.Update.Data.init(solution: content.solution, presentUser: nil))
                        return solution.save(on: self.database)
                }
        }
    }

    func find(id: LectureNote.ID) -> EventLoopFuture<LectureNote> {
        LectureNote.DatabaseModel.query(on: database)
            .withDeleted()
            .join(superclass: TaskDatabaseModel.self, with: LectureNote.DatabaseModel.self)
            .join(children: \TaskDatabaseModel.$solutions)
            .filter(\.$id == id)
            .first(TaskDatabaseModel.self, TaskSolution.DatabaseModel.self)
            .unwrap(or: Abort(.badRequest))
            .flatMapThrowing { (task, solution) in
                try LectureNote(
                    id: task.requireID(),
                    question: task.question,
                    solution: solution.solution,
                    subtopicID: task.$subtopic.id,
                    userID: task.$creator.id
                )
        }
    }
}
