//
//  FlashCardRepository.swift
//  KognitaCore
//
//  Created by Mats Mollestad on 11/04/2019.
//

import Vapor
import FluentKit

/// The functionality needed to handle typing tasks
public protocol TypingTaskRepository: DeleteModelRepository {

    /// Create a typing task
    /// - Parameters:
    ///   - content: The data defining the typing task
    ///   - user: The user creating the task
    func create(from content: TypingTask.Create.Data, by user: User?) throws -> EventLoopFuture<TypingTask.Create.Response>

    /// Updated the typing task
    /// - Parameters:
    ///   - id: The id of the task to update
    ///   - data: The updated task information
    ///   - user: The user updating the task
    func updateModelWith(id: Int, to data: TypingTask.Update.Data, by user: User) throws -> EventLoopFuture<TypingTask.Update.Response>

    /// Imports some task content
    /// - Parameters:
    ///   - task: The task information to import
    ///   - subtopic: The subtopic the task is assosiated with
    ///   - examID: The exam the task is assosiated with
    func importTask(from task: TypingTask.Import, in subtopic: Subtopic, examID: Exam.ID?, resourceMap: [Resource.ID: Resource.ID]) throws -> EventLoopFuture<Void>

    /// Returns the information needed to display a GUI edit screen for a given task id
    /// - Parameter taskID: The task id to get the information for
    func modifyContent(forID taskID: Task.ID) throws -> EventLoopFuture<TypingTask.ModifyContent>

    /// Creates an answer for a given task
    /// - Parameters:
    ///   - task: The task id to create the answer for
    ///   - submit: The submitted answer
    func createAnswer(for task: TypingTask.ID, withTextSubmittion submit: String) -> EventLoopFuture<TaskAnswer>

    /// Returns an answer assoisated with a session and task if it exists
    /// - Parameters:
    ///   - sessionID: The session id the answer is assosiated with
    ///   - taskID: The task id the asnwer is assosiated with
    func typingTaskAnswer(in sessionID: Sessions.ID, taskID: Task.ID) -> EventLoopFuture<TypingTask.Answer?>

    /// Permanently delete the task
    /// - Parameters:
    ///   - taskID: The task id to delete
    ///   - user: The user deleteing the task
    func forceDelete(taskID: Task.ID, by user: User) -> EventLoopFuture<Void>

    /// Returns all the answers submitted for a given subject id
    /// - Parameter subjectID: The id of the subject
    func allTaskAnswers(for subjectID: Subject.ID) -> EventLoopFuture<[TypingTask.AnswerResult]>
}

extension TypingTask.Create.Data: TaskCreationContentable {
    public var isDraft: Bool { false }
}
extension LectureNote.Create.Data: TaskCreationContentable {
    public var isTestable: Bool { false }
    public var isDraft: Bool { true }
    public var examID: Exam.ID? { nil }
    public var resources: [Resource.Create] { [] }
}

extension KognitaModels.TypingTask {
    init(task: Task) {
        self.init(
            id: task.id,
            subtopicID: task.subtopicID,
            description: task.description,
            question: task.question,
            creatorID: task.creatorID,
            exam: task.exam,
            isTestable: task.isTestable,
            createdAt: task.createdAt,
            updatedAt: task.updatedAt,
            deletedAt: task.deletedAt,
            editedTaskID: task.editedTaskID
        )
    }

    init(task: TaskDatabaseModel) {
        self.init(
            id: task.id ?? 0,
            subtopicID: task.$subtopic.id,
            description: task.description,
            question: task.question,
            creatorID: task.$creator.id,
            exam: (try? task.exam?.content().compactData),
            isTestable: task.isTestable,
            createdAt: task.createdAt,
            updatedAt: task.updatedAt,
            deletedAt: task.deletedAt,
            editedTaskID: nil
        )
    }
}

extension KognitaModels.GenericTask {
    init(task: TaskDatabaseModel, exam: Exam?) {
        self.init(
            id: task.id ?? 0,
            subtopicID: task.$subtopic.id,
            description: task.description,
            question: task.question,
            creatorID: task.$creator.id,
            exam: exam?.compactData,
            isTestable: task.isTestable,
            createdAt: task.createdAt,
            updatedAt: task.updatedAt,
            editedTaskID: nil,
            deletedAt: task.deletedAt
        )
    }
}
