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

public protocol SubjectRepositoring: DeleteModelRepository {
    func all() throws -> EventLoopFuture<[Subject]>
    func find(_ id: Subject.ID, or error: Error) -> EventLoopFuture<Subject>
    func overviewFor(id: Subject.ID) -> EventLoopFuture<Subject.Overview>
    func overviewContaining(subtopicID: Subtopic.ID) -> EventLoopFuture<Subject.Overview>
    func create(from content: Subject.Create.Data, by user: User?) throws -> EventLoopFuture<Subject.Create.Response>
    func updateModelWith(id: Int, to data: Subject.Update.Data, by user: User) throws -> EventLoopFuture<Subject.Update.Response>
    func subjectFor(topicID: Topic.ID) -> EventLoopFuture<Subject>
    func allSubjects(for user: User, searchQuery: Subject.ListOverview.SearchQuery) -> EventLoopFuture<[Subject.ListOverview]>
    func allActive(for user: User) throws -> EventLoopFuture<[Subject]>
    func active(subject: Subject, for user: User) throws -> EventLoopFuture<User.ActiveSubject?>
    func mark(active subject: Subject, canPractice: Bool, for user: User) throws -> EventLoopFuture<Void>
    func mark(inactive subject: Subject, for user: User) throws -> EventLoopFuture<Void>
    func grantModeratorPrivilege(for userID: User.ID, in subjectID: Subject.ID, by moderator: User) throws -> EventLoopFuture<Void>
    func revokeModeratorPrivilege(for userID: User.ID, in subjectID: Subject.ID, by moderator: User) throws -> EventLoopFuture<Void>
    func compendium(for subjectID: Subject.ID, filter: SubjectCompendiumFilter, for userID: User.ID) throws -> EventLoopFuture<Subject.Compendium>
    func subjectIDFor(taskIDs: [Task.ID]) -> EventLoopFuture<Subject.ID>
    func subjectIDFor(topicIDs: [Topic.ID]) -> EventLoopFuture<Subject.ID>
    func subjectIDFor(subtopicIDs: [Subtopic.ID]) -> EventLoopFuture<Subject.ID>
    func subject(for session: PracticeSessionRepresentable) -> EventLoopFuture<Subject>
    func importContent(_ content: Subject.Import) -> EventLoopFuture<Subject>
    func importContent(in subject: Subject, peerWise: [TaskPeerWise], user: User) throws -> EventLoopFuture<Void>
    func tasksWith(subjectID: Subject.ID) -> EventLoopFuture<[GenericTask]>
    func tasksWith(subjectID: Subject.ID, user: User, query: TaskOverviewQuery?, maxAmount: Int?, withSoftDeleted: Bool) -> EventLoopFuture<[CreatorTaskContent]>
}
