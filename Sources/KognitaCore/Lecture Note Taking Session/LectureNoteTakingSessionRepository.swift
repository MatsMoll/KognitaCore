//
//  LectureNoteTakingSessionRepository.swift
//  KognitaCore
//
//  Created by Mats Mollestad on 28/09/2020.
//

import Fluent

public protocol LectureNoteTakingSessionRepository {
    func create(for user: User) -> EventLoopFuture<LectureNote.TakingSession>
    func isOwnerOf(sessionID: LectureNote.TakingSession.ID, userID: User.ID) -> EventLoopFuture<Bool>
}

extension LectureNote.TakingSession {
    struct DatabaseRepository: LectureNoteTakingSessionRepository {

        let database: Database

        func create(for user: User) -> EventLoopFuture<LectureNote.TakingSession> {
            let session = LectureNote.TakingSession.DatabaseModel(userID: user.id)

            return session.create(on: database)
                .flatMapThrowing {
                    try LectureNote.TakingSession(id: session.requireID(), userID: session.$user.id, createdAt: session.createdAt ?? .now)
            }
        }

        func isOwnerOf(sessionID: LectureNote.TakingSession.ID, userID: User.ID) -> EventLoopFuture<Bool> {
            LectureNote.TakingSession.DatabaseModel.query(on: database)
                .filter(\.$user.$id == userID)
                .filter(\.$id == sessionID)
                .first()
                .map { $0 != nil }
        }
    }
}
