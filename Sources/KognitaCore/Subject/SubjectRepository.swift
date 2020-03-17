//
//  SubjectRepository.swift
//  App
//
//  Created by Mats Mollestad on 02/03/2019.
//

import Vapor
import FluentPostgreSQL

public protocol SubjectRepositoring:
    CreateModelRepository,
    UpdateModelRepository,
    DeleteModelRepository,
    RetriveAllModelsRepository
    where
    Model           == Subject,
    CreateData      == Subject.Create.Data,
    CreateResponse  == Subject.Create.Response,
    UpdateData      == Subject.Edit.Data,
    UpdateResponse  == Subject.Edit.Response,
    ResponseModel   == Subject
{
    static func allSubjects(for user: User, on conn: DatabaseConnectable) throws -> EventLoopFuture<[Subject.ListOverview]>
    static func allActive(for user: User, on conn: DatabaseConnectable) throws -> EventLoopFuture<[Subject]>
    static func active(subject: Subject, for user: User, on conn: DatabaseConnectable) throws -> EventLoopFuture<User.ActiveSubject?>
    static func mark(active subject: Subject, canPractice: Bool, for user: User, on conn: DatabaseConnectable) throws -> EventLoopFuture<Void>
    static func grantModeratorPrivilege(for userID: User.ID, in subjectID: Subject.ID, by moderator: User, on conn: DatabaseConnectable) throws -> EventLoopFuture<Void>
    static func revokeModeratorPrivilege(for userID: User.ID, in subjectID: Subject.ID, by moderator: User, on conn: DatabaseConnectable) throws -> EventLoopFuture<Void>
}

extension Subject {
    
    public enum Create {
        public struct Data : Content {
            let name: String
            let colorClass: Subject.ColorClass
            let description: String
            let category: String
        }
        
        public typealias Response = Subject
    }
    
    public typealias Edit = Create
}
