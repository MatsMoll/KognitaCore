import Vapor
import FluentKit

public enum UpdateResultOutcom {
    case created(result: TaskResult)
    case updated(result: TaskResult)
}

public protocol TaskResultRepositoring {
    func getResults() -> EventLoopFuture<[UserResultOverview]>
    func getAllResults(for userId: User.ID) -> EventLoopFuture<[TaskResult]>
    func getUserLevel(for userId: User.ID, in topics: [Topic.ID]) -> EventLoopFuture<[Topic.UserLevel]>
    func getUserLevel(in subject: Subject, userId: User.ID) -> EventLoopFuture<User.SubjectLevel>
    func getSpaceRepetitionTask(for userID: User.ID, sessionID: PracticeSession.ID) -> EventLoopFuture<SpaceRepetitionTask?>
    func createResult(from result: TaskSubmitResultRepresentable, userID: User.ID, with sessionID: Sessions.ID?) -> EventLoopFuture<TaskResult>
    func updateResult(with result: TaskSubmitResultRepresentable, userID: User.ID, with sessionID: Sessions.ID?) -> EventLoopFuture<UpdateResultOutcom>
    func getLastResult(for taskID: Task.ID, by userId: User.ID) -> EventLoopFuture<TaskResult?>
    func getResult(for taskID: Task.ID, by userID: User.ID, sessionID: Int) -> EventLoopFuture<TaskResult?>
    func getAmountHistory(for user: User, in subjectId: Subject.ID, numberOfWeeks: Int) -> EventLoopFuture<[TaskResult.History]>
    func getAmountHistory(for user: User, numberOfWeeks: Int) -> EventLoopFuture<[TaskResult.History]>

    func recommendedRecap(for user: User.ID, upperBoundDays: Int, lowerBoundDays: Int) -> EventLoopFuture<[RecommendedRecap]>
}
