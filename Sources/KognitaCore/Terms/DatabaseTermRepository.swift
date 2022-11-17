//
//  DatabaseTermRepository.swift
//  
//
//  Created by Mats Mollestad on 08/01/2021.
//

import FluentKit
import Vapor

extension User {
    static let unknownUser = User(id: 1, username: "Unknown", email: "unknown@kognita.no", registrationDate: .now, isAdmin: true, isEmailVerified: true, pictureUrl: nil)
}

struct DatabaseTermRepository: TermRepository {

    let database: Database
    let repositories: RepositoriesRepresentable

    private var resourceRepository: ResourceRepository { repositories.resourceRepository }
    private var multipleChoiceRepository: MultipleChoiseTaskRepository { repositories.multipleChoiceTaskRepository }

    init(database: Database, repositories: RepositoriesRepresentable) {
        self.database = database
        self.repositories = repositories
    }

    func create(term: Term.Create.Data) -> EventLoopFuture<Term.ID> {
        Term.DatabaseModel.query(on: database)
            .filter(\.$subtopic.$id == term.subtopicID)
            .filter(\.$term == term.term)
            .first()
            .flatMap { existingTerm in
                if let termID = existingTerm?.id {
                    return database.eventLoop.future(termID)
                }
                let mewTerm = Term.DatabaseModel(data: term)
                return mewTerm
                    .create(on: database)
                    .flatMapThrowing { try mewTerm.requireID() }
            }
    }

    func with(id: Term.ID) -> EventLoopFuture<Term> {
        Term.DatabaseModel.find(id, on: database).unwrap(or: Abort(.badRequest)).content()
    }

    func updateTermWith(id: Term.ID, to data: Term.Create.Data) -> EventLoopFuture<Void> {
        database.eventLoop.future(error: Abort(.notImplemented))
    }

    func deleteTermWith(id: Term.ID) -> EventLoopFuture<Void> {
        Term.DatabaseModel.find(id, on: database)
            .unwrap(or: Abort(.badRequest))
            .flatMap { term in
                deleteTasksConnected(toTermID: id)
                    .transform(to: term)
            }
            .delete(on: database)
    }
    
    private func deleteTasksConnected(toTermID termID: Term.ID) -> EventLoopFuture<Void> {
        Term.TaskPivot.query(on: database)
            .filter(\.$term.$id == termID)
            .all(\.$task.$id)
            .flatMapEachCompact(on: database.eventLoop, { (taskID) in
                TaskDatabaseModel.find(taskID, on: database)
            })
            .flatMapEach(on: database.eventLoop) { (task) in
                task.delete(on: database)
            }
            .transform(to: ())
    }

    func generateMultipleChoiceTasksWith(termIDs: Set<Term.ID>, toSubtopicID subtopicID: Subtopic.ID) -> EventLoopFuture<Void> {

        Term.DatabaseModel.query(on: database)
            .filter(\.$id ~~ termIDs)
            .all()
            .flatMap { terms in

                resourceRepository.resourcesFor(termIDs: terms.compactMap { $0.id })
                    .failableFlatMap { resources in

                        try multipleChoiceData(from: terms, subtopicID: subtopicID)
                            .map {
                                try multipleChoiceRepository.create(from: $0, by: .unknownUser)
                                    .failableFlatMap { task in
                                        try terms.map { term in
                                            try Term.TaskPivot(taskID: task.id, termID: term.requireID())
                                                .create(on: database)
                                        }
                                        .flatten(on: database.eventLoop)
                                        .flatMap {
                                            resources.map { resource in
                                                resourceRepository.connect(taskID: task.id, to: resource.id)
                                            }
                                            .flatten(on: database.eventLoop)
                                        }
                                }

                            }
                            .flatten(on: database.eventLoop)
                            .transform(to: ())
                }
            }
    }

    func allWith(subtopicID: Subtopic.ID) -> EventLoopFuture<[Term]> {
        Term.DatabaseModel.query(on: database)
            .filter(\.$subtopic.$id == subtopicID)
            .all()
            .content()
    }

    func allWith(subtopicIDs: Set<Subtopic.ID>) -> EventLoopFuture<[Term]> {
        Term.DatabaseModel.query(on: database)
            .filter(\.$subtopic.$id ~~ subtopicIDs)
            .all()
            .content()
    }

    func allWith(subjectID: Subject.ID) -> EventLoopFuture<[Term]> {
        Term.DatabaseModel.query(on: database)
            .join(parent: \Term.DatabaseModel.$subtopic)
            .join(parent: \Subtopic.DatabaseModel.$topic)
            .filter(Topic.DatabaseModel.self, \.$subject.$id == subjectID)
            .all()
            .content()
    }
    
    func allWith(topicID: Topic.ID) -> EventLoopFuture<[Term]> {
        Term.DatabaseModel.query(on: database)
            .join(parent: \.$subtopic)
            .filter(Subtopic.DatabaseModel.self, \Subtopic.DatabaseModel.$topic.$id == topicID)
            .all()
            .content()
    }

    func importContent(term: Term.Import, for subtopicID: Subtopic.ID, resourceMap: [Resource.ID: Resource.ID]) -> EventLoopFuture<Void> {
        do {
            return create(
                term: Term.Create.Data(
                    term: term.term,
                    meaning: try term.meaning.cleanXSS(whitelist: .relaxed()),
                    subtopicID: subtopicID
                )
            ).flatMap { termID in
                guard let sources = term.sources else { return database.eventLoop.future() }
                return sources.compactMap { oldResourceID in
                    resourceMap[oldResourceID]
                }.map { resourceID in
                    resourceRepository.connect(termID: termID, to: resourceID)
                }
                .flatten(on: database.eventLoop)
            }
        } catch {
            return database.eventLoop.future(error: Abort(.internalServerError, reason: "Unable to clean the term meaning for XSS"))
        }
    }

    private func multipleChoiceData(from terms: [Term.DatabaseModel], subtopicID: Subtopic.ID) -> [MultipleChoiceTask.Create.Data] {

        var multipleChoiceTasks = [MultipleChoiceTask.Create.Data]()
        if terms.count > 2 {

            let termContent = terms.compactMap { try? $0.content() }
            var termGroups: [[Term]] = [termContent]
            var numberOfGroupes = terms.count / 4
            let remainingTerms = terms.count % 4

            if numberOfGroupes >= 2 || (numberOfGroupes == 1 && remainingTerms > 2) {
                var unselectedChoices = termContent
                termGroups = []
                if numberOfGroupes == 1 && remainingTerms > 2 {
                    numberOfGroupes += 1
                }
                for _ in 0..<numberOfGroupes {
                    termGroups.append([])
                }
                var groupIndex = 0
                while unselectedChoices.isEmpty == false {
                    let index = Int.random(in: 0..<unselectedChoices.count)
                    let term = unselectedChoices[index]
                    unselectedChoices.remove(at: index)
                    termGroups[groupIndex] = termGroups[groupIndex] + [term]
                    groupIndex = (groupIndex + 1) % numberOfGroupes
                }
            }

            for termGroup in termGroups {

                let generatedSolution = termGroup.reduce("<dl>") { $0 + "<dt>\($1.term)</dt><dd>\($1.meaning)</dd>" } + "</dl>"

                for term in termGroup {
                    multipleChoiceTasks.append(
                        MultipleChoiceTask.Create.Data(
                            subtopicId: subtopicID,
                            description: nil,
                            question: "Hva beskriver \"\(term.term)\"?",
                            solution: generatedSolution,
                            isMultipleSelect: false,
                            examID: nil,
                            isTestable: false,
                            choises: termGroup.map {
                                MultipleChoiceTaskChoice.Create.Data(choice: $0.meaning, isCorrect: $0.id == term.id)
                            },
                            resources: []
                        )
                    )
                }

                for term in termGroup {
                    multipleChoiceTasks.append(
                        MultipleChoiceTask.Create.Data(
                            subtopicId: subtopicID,
                            description: nil,
                            question: "Hvilket begrep passer best med \"\(term.meaning)\"?",
                            solution: generatedSolution,
                            isMultipleSelect: false,
                            examID: nil,
                            isTestable: false,
                            choises: termGroup.map {
                                MultipleChoiceTaskChoice.Create.Data(choice: $0.term, isCorrect: $0.id == term.id)
                            },
                            resources: []
                        )
                    )
                }
            }
        }
        return multipleChoiceTasks
    }
}
