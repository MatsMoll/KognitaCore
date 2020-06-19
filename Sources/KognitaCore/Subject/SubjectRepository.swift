//
//  SubjectRepository.swift
//  App
//
//  Created by Mats Mollestad on 02/03/2019.
//

import Vapor
import FluentPostgreSQL

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
    func allSubjects(for user: User) throws -> EventLoopFuture<[Subject.ListOverview]>
    func allActive(for user: User) throws -> EventLoopFuture<[Subject]>
    func active(subject: Subject, for user: User) throws -> EventLoopFuture<User.ActiveSubject?>
    func mark(active subject: Subject, canPractice: Bool, for user: User) throws -> EventLoopFuture<Void>
    func mark(inactive subject: Subject, for user: User) throws -> EventLoopFuture<Void>
    func grantModeratorPrivilege(for userID: User.ID, in subjectID: Subject.ID, by moderator: User) throws -> EventLoopFuture<Void>
    func revokeModeratorPrivilege(for userID: User.ID, in subjectID: Subject.ID, by moderator: User) throws -> EventLoopFuture<Void>
    func compendium(for subjectID: Subject.ID, filter: SubjectCompendiumFilter) throws -> EventLoopFuture<Subject.Compendium>
    func subjectIDFor(taskIDs: [Task.ID]) -> EventLoopFuture<Subject.ID>
    func subjectIDFor(topicIDs: [Topic.ID]) -> EventLoopFuture<Subject.ID>
    func subjectIDFor(subtopicIDs: [Subtopic.ID]) -> EventLoopFuture<Subject.ID>
    func subject(for session: PracticeSessionRepresentable) -> EventLoopFuture<Subject>
    func importContent(_ content: SubjectExportContent) -> EventLoopFuture<Subject>
    func importContent(in subject: Subject, peerWise: [Task.PeerWise], user: User) throws -> EventLoopFuture<Void>
}
