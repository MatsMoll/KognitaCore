//
//  TermRepository.swift
//  
//
//  Created by Mats Mollestad on 08/01/2021.
//

import Vapor

public protocol TermRepository {
    func create(term: Term.Create.Data) -> EventLoopFuture<Term.ID>
    func updateTermWith(id: Term.ID, to data: Term.Create.Data) -> EventLoopFuture<Void>
    func deleteTermWith(id: Term.ID) -> EventLoopFuture<Void>

    func generateMultipleChoiceTasksWith(termIDs: Set<Term.ID>, toSubtopicID subtopicID: Subject.ID) -> EventLoopFuture<Void>

    func allWith(subtopicID: Subtopic.ID) -> EventLoopFuture<[Term]>

    func allWith(subtopicIDs: Set<Subtopic.ID>) -> EventLoopFuture<[Term]>

    func allWith(subjectID: Subject.ID) -> EventLoopFuture<[Term]>

    func with(id: Term.ID) -> EventLoopFuture<Term>

    func importContent(term: Term.Import, for subtopicID: Subtopic.ID, resourceMap: [Resource.ID: Resource.ID]) -> EventLoopFuture<Void>
}
