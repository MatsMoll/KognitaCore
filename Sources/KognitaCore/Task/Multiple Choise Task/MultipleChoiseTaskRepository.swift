//
//  MultipleChoiseTaskRepository.swift
//  KognitaCore
//
//  Created by Mats Mollestad on 11/04/2019.
//

import FluentSQL
import Vapor

extension MultipleChoiceTaskChoice.Answered: Content {}
extension MultipleChoiceTaskChoice.Result: Content {}

/// The functionality needed for handeling multiple choice tasks
public protocol MultipleChoiseTaskRepository: DeleteModelRepository {
    /// Creates a multiple choice task
    /// - Parameters:
    ///   - content: The content assosiated with the task
    ///   - user: The user creating the task
    func create(from content: MultipleChoiceTask.Create.Data, by user: User?) throws -> EventLoopFuture<MultipleChoiceTask.Create.Response>

    /// Updates a task
    /// - Parameters:
    ///   - id: The id of the task to update
    ///   - data: The data to update the task to
    ///   - user: The user updating the task
    func updateModelWith(id: Int, to data: MultipleChoiceTask.Update.Data, by user: User) throws -> EventLoopFuture<MultipleChoiceTask.Update.Response>

    /// The task for a given id
    /// - Parameter taskID: The id of the task
    func task(withID taskID: Task.ID) throws -> EventLoopFuture<MultipleChoiceTask>

    /// The data needed to present a GUI that modifies a task
    /// - Parameter taskID: The id of the task to retrive
    func modifyContent(forID taskID: Task.ID) throws -> EventLoopFuture<MultipleChoiceTask.ModifyContent>

    /// Creates an given answer that is assosiated with a session
    /// - Parameters:
    ///   - submit: The answer that was submitted
    ///   - sessionID: The session the answer was submitted in
    func create(answer submit: MultipleChoiceTask.Submit, sessionID: TestSession.ID) -> EventLoopFuture<[TaskAnswer]>

    /// Evaluate the score for some selected choices in a task
    /// - Parameters:
    ///   - choises: The selected choicies
    ///   - taskID: The id of the task
    func evaluate(_ choises: [MultipleChoiceTaskChoice.ID], for taskID: MultipleChoiceTask.ID) throws -> EventLoopFuture<TaskSessionResult<[MultipleChoiceTaskChoice.Result]>>

    /// Imports a task
    /// - Parameters:
    ///   - taskContent: The content defining the task
    ///   - subtopic: The subtopic to import the task in
    ///   - examID: The exam id to assosiate the task with
    ///   - resourceMap: A dict prev resource.id's used in the import to the saved resouces
    func importTask(from taskContent: MultipleChoiceTask.Import, in subtopic: Subtopic, examID: Exam.ID?, resourceMap: [Resource.ID: Resource.ID]) throws -> EventLoopFuture<Void>

    /// Creates an answer for a given choice in a session
    /// - Parameters:
    ///   - choiseID: The id assosiated with the choice
    ///   - sessionID: The id assosiated with the session
    func createAnswer(choiseID: MultipleChoiceTaskChoice.ID, sessionID: TestSession.ID) -> EventLoopFuture<TaskAnswer>

    /// The different choices in a given task
    /// - Parameter taskID: The id assosiated with the given task
    func choisesFor(taskID: MultipleChoiceTask.ID) -> EventLoopFuture<[MultipleChoiceTaskChoice]>

    /// The correct choices for a given task
    /// - Parameter taskID: The id assosiated with the given task
    func correctChoisesFor(taskID: Task.ID) -> EventLoopFuture<[MultipleChoiceTaskChoice]>

    /// Evaluates some selected choices together with the correct choices
    /// - Parameters:
    ///   - choises: The selected choices
    ///   - correctChoises: The correct choices
    func evaluate(_ choises: [MultipleChoiceTaskChoice.ID], agenst correctChoises: [MultipleChoiceTaskChoice]) throws -> TaskSessionResult<[MultipleChoiceTaskChoice.Result]>

    /// The sumbitted answers for a given session and task
    /// - Parameters:
    ///   - sessionID: The id assosiated with the sesison to fetch the data for
    ///   - taskID: The id assosiated with the task to fetch the data for
    func multipleChoiseAnswers(in sessionID: Sessions.ID, taskID: Task.ID) -> EventLoopFuture<[MultipleChoiceTaskChoice.Answered]>

    /// Delete the task permanently
    /// - Parameters:
    ///   - taskID: The id of the task to delete
    ///   - user: The user deleting the task
    func forceDelete(taskID: Task.ID, by user: User) -> EventLoopFuture<Void>
}
