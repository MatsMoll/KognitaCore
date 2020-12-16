//
//  SubjectRepository.swift
//  App
//
//  Created by Mats Mollestad on 02/03/2019.
//

import Vapor

public struct SubjectCompendiumFilter: Codable {
    let subtopicIDs: Set<Subtopic.ID>?
}

/// The functionality needed for to controll the subject functionality
public protocol SubjectRepositoring: DeleteModelRepository {

    /// Returns all the differnet subjects
    func all() throws -> EventLoopFuture<[Subject]>

    /// Returns a subject for a given id
    /// - Parameters:
    ///   - id: The id of the subject
    ///   - error: The Error to throw if the subject is not found
    func find(_ id: Subject.ID, or error: Error) -> EventLoopFuture<Subject>

    /// Returns an overview for a given subject id
    /// - Parameter id: The id of the subject
    func overviewFor(id: Subject.ID) -> EventLoopFuture<Subject.Overview>

    /// Returns a overview of a subject for a given subtopicID
    /// - Parameter subtopicID: The subtopic id
    func overviewContaining(subtopicID: Subtopic.ID) -> EventLoopFuture<Subject.Overview>

    /// Creates a new subject
    /// - Parameters:
    ///   - content: The content needed to create a new subject
    ///   - user: The user creating the subject
    func create(from content: Subject.Create.Data, by user: User?) throws -> EventLoopFuture<Subject.Create.Response>

    /// Update a existing subject
    /// - Parameters:
    ///   - id: The id for the subject to update
    ///   - data: The data to update the subject to
    ///   - user: The user updating the subject
    func updateModelWith(id: Int, to data: Subject.Update.Data, by user: User) throws -> EventLoopFuture<Subject.Update.Response>

    /// Returns the subject for a given topic id
    /// - Parameter topicID: The topic id
    func subjectFor(topicID: Topic.ID) -> EventLoopFuture<Subject>

    /// Returns all subjects for a given user
    /// - Parameters:
    ///   - user: The user requesting the subjects
    ///   - searchQuery: A search query if wanted
    func allSubjects(for userID: User.ID?, searchQuery: Subject.ListOverview.SearchQuery?) -> EventLoopFuture<[Subject.ListOverview]>

    /// Returns all the active subjects for a user
    /// - Parameter userID: The id of the user making the request
    func allActive(for userID: User.ID) -> EventLoopFuture<[Subject]>

    /// Returns the information stored for an active subject if it exists
    /// - Parameters:
    ///   - subject: The subject to fetch the info for
    ///   - user: The user requesting the data
    func active(subject: Subject, for user: User) throws -> EventLoopFuture<User.ActiveSubject?>

    /// Mark a subject as active
    /// - Parameters:
    ///   - subject: The subject to mark
    ///   - canPractice: If the user can practice in the subject
    ///   - user: The user making the request
    func mark(active subject: Subject, canPractice: Bool, for user: User) throws -> EventLoopFuture<Void>

    /// Make a subject inactive
    /// - Parameters:
    ///   - subject: The subject to mark
    ///   - user: The user making the request
    func mark(inactive subject: Subject, for user: User) throws -> EventLoopFuture<Void>

    /// Grant a user moderator privilege
    /// - Parameters:
    ///   - userID: The user to grant the privelage for
    ///   - subjectID: The id of the subject to grant the privelage for
    ///   - moderator: A exisitng moderator
    func grantModeratorPrivilege(for userID: User.ID, in subjectID: Subject.ID, by moderator: User) throws -> EventLoopFuture<Void>

    /// Revoe a moderator privelage
    /// - Parameters:
    ///   - userID: The id of the user to revoke the privelage for
    ///   - subjectID: The id of the subject to revoke it in
    ///   - moderator: An existing moderator
    func revokeModeratorPrivilege(for userID: User.ID, in subjectID: Subject.ID, by moderator: User) throws -> EventLoopFuture<Void>

    /// Return a compendium in a subject
    /// - Parameters:
    ///   - subjectID: The id of the subject to return the compendium for
    ///   - filter: A filter if wanted
    ///   - userID: The id of the user makeing the request
    func compendium(for subjectID: Subject.ID, filter: SubjectCompendiumFilter, for userID: User.ID) throws -> EventLoopFuture<Subject.Compendium>

    /// Returns the subject id for a given taskIDs
    /// - Parameter taskIDs: The taskIDs
    func subjectIDFor(taskIDs: [Task.ID]) -> EventLoopFuture<Subject.ID>

    /// Returns the subject id for a set of topic ids
    /// - Parameter topicIDs: The topic ids
    func subjectIDFor(topicIDs: [Topic.ID]) -> EventLoopFuture<Subject.ID>

    /// Returns the subject id for a set of subtopic ids
    /// - Parameter subtopicIDs: The subtopic ids
    func subjectIDFor(subtopicIDs: [Subtopic.ID]) -> EventLoopFuture<Subject.ID>

    /// Returns the subject for a given session
    /// - Parameter session: The session
    func subject(for session: PracticeSessionRepresentable) -> EventLoopFuture<Subject>

    /// Imports a new Subject
    /// - Parameter content: The content to import
    func importContent(_ content: Subject.Import) -> EventLoopFuture<Subject>

    /// Import a set of `TaskPeerWise` task into an existing subject
    /// - Parameters:
    ///   - subject: The subject to import into
    ///   - peerWise: The tasks to import
    ///   - user: The user making the request
    func importContent(in subject: Subject, peerWise: [TaskPeerWise], user: User) throws -> EventLoopFuture<Void>

    /// Returns all tasks connected to a subject
    /// - Parameter subjectID: The id of the subject
    func tasksWith(subjectID: Subject.ID) -> EventLoopFuture<[GenericTask]>

    /// Returns a set of tasks in a given subject with a filter
    /// - Parameters:
    ///   - subjectID: The id of the subject
    ///   - user: The user making the request
    ///   - query: The optional query
    ///   - maxAmount: The max amount of tasks
    ///   - withSoftDeleted: If it should return tombstoned data
    func tasksWith(subjectID: Subject.ID, user: User, query: TaskOverviewQuery?, maxAmount: Int?, withSoftDeleted: Bool) -> EventLoopFuture<[CreatorTaskContent]>
}
