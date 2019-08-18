//
//  RenderPracticing.swift
//  App
//
//  Created by Mats Mollestad on 22/01/2019.
//

import Vapor

/// A protocol for a task tha can be practiced on
public protocol RenderTaskPracticing {

    /// The id of the task
    var id: Int? { get }

    /// Render a task in practice mode
    ///
    /// - Parameters:
    ///     - req:      The http request
    ///     - session:  The session object the task is rendered for
    ///     - user:     The user to render the task for
    ///
    /// - Returns:
    ///     A renderd `View` of the task
    func render(session: PracticeSession, for user: User, on conn: DatabaseConnectable) throws -> Future<HTTPResponse>
}

public final class PracticeSessionResult<T: Content>: Content, TaskSubmitResultable {

    public var change: Double?

    public let unforgivingScore: Double

    public let forgivingScore: Double

    public var progress: Double

    public let result: T


    init(result: T, unforgivingScore: Double, forgivingScore: Double, progress: Double, change: Double? = nil) {
        self.result = result
        self.unforgivingScore = unforgivingScore
        self.forgivingScore = forgivingScore
        self.progress = progress
        self.change = change
    }
}
