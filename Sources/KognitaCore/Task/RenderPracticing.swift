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
    func render(session: PracticeSession, for user: User, on conn: DatabaseConnectable) throws -> EventLoopFuture<HTTPResponse>
}

public final class TaskSessionResult<T: Content>: Content, TaskSubmitResultable {

    public let score: Double

    public var progress: Double

    public let result: T


    init(
        result: T,
        score: Double,
        progress: Double
    ) {
        self.result = result
        self.score = score
        self.progress = progress        
    }

    public struct Representable: TaskSubmitResultRepresentable {
        public let result: TaskSessionResult
        public let taskID: Task.ID

        public var timeUsed: TimeInterval? { nil }
        public var score: Double { result.score }
    }

    func representableWith(taskID: Task.ID) -> Representable {
        .init(result: self, taskID: taskID)
    }
}
