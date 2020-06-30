import Vapor
import FluentKit

public protocol TaskResultRepositoring {
    static func getResults(on database: Database) -> EventLoopFuture<[UserResultOverview]>
    static func getAllResults(for userId: User.ID, with database: Database) throws -> EventLoopFuture<[TaskResult]>
    static func getUserLevel(for userId: User.ID, in topics: [Topic.ID], on database: Database) throws -> EventLoopFuture<[User.TopicLevel]>
    static func getSpaceRepetitionTask(for userID: User.ID, sessionID: PracticeSession.ID, on database: Database) throws -> EventLoopFuture<SpaceRepetitionTask?>
}
