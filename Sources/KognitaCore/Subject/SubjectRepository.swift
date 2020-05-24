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

public protocol SubjectRepositoring: CreateModelRepository,
    UpdateModelRepository,
    DeleteModelRepository,
    RetriveAllModelsRepository,
    RetriveModelRepository
    where
    Model           == Subject,
    CreateData      == Subject.Create.Data,
    CreateResponse  == Subject.Create.Response,
    UpdateData      == Subject.Edit.Data,
    UpdateResponse  == Subject.Edit.Response,
    ResponseModel   == Subject {
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
}

extension Subject {

    public enum Create {
        public struct Data: Content {
            let name: String
            let colorClass: Subject.ColorClass = .primary
            let description: String
            let category: String
        }

        public typealias Response = Subject
    }

    public typealias Edit = Create
}
