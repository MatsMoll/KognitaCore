
import Vapor

public protocol TaskResultRepositoring {
    static func getResults(on conn: DatabaseConnectable) -> EventLoopFuture<[UserResultOverview]>
    static func getAllResults(for userId: User.ID, with conn: DatabaseConnectable) throws -> EventLoopFuture<[TaskResult]>
}
