import Vapor
import FluentKit

public enum UpdateResultOutcom {
    case created(result: TaskResult)
    case updated(result: TaskResult)
}

/// The functionality needed to handle task results
public protocol TaskResultRepositoring {
    /// Returns all the results for each user
    func getResults() -> EventLoopFuture<[UserResultOverview]>

    /// Returns all the reulst for a given user
    /// - Parameter userId: The user to get the results for
    func getAllResults(for userId: User.ID) -> EventLoopFuture<[TaskResult]>

    /// Returns the user level for a user
    /// - Parameters:
    ///   - userId: The user id of the user to fetch the results for
    ///   - topics: The topics to fetch the level for
    func getUserLevel(for userId: User.ID, in topics: [Topic.ID]) -> EventLoopFuture<[Topic.UserLevel]>

    /// Returns the users level in a given subject
    /// - Parameters:
    ///   - subject: The subject to fetch the user level for
    ///   - userId: The user to fetch the results for
    func getUserLevel(in subject: Subject, userId: User.ID) -> EventLoopFuture<User.SubjectLevel>

    /// Get the most relevent tasks according to spaced repetition
    /// - Parameters:
    ///   - userID: The user to calculate for
    ///   - sessionID: The session to fetch the task for
    func getSpaceRepetitionTask(for userID: User.ID, sessionID: PracticeSession.ID) -> EventLoopFuture<SpaceRepetitionTask?>

    /// Create a result
    /// - Parameters:
    ///   - result: The result to save
    ///   - userID: The user to save the results for
    ///   - sessionID: The session the user performed the result
    func createResult(from result: TaskSubmitResultRepresentable, userID: User.ID, with sessionID: Sessions.ID?) -> EventLoopFuture<TaskResult>

    /// Update a result
    /// - Parameters:
    ///   - result: The result to update it to
    ///   - userID: The id of the user updating the result
    ///   - sessionID: The session the results are related to
    func updateResult(with result: TaskSubmitResultRepresentable, userID: User.ID, with sessionID: Sessions.ID?) -> EventLoopFuture<UpdateResultOutcom>

    /// Returns the last result for a given task an user
    /// - Parameters:
    ///   - taskID: The task to fetch the last result for
    ///   - userId: The user to fetch the result for
    func getLastResult(for taskID: Task.ID, by userId: User.ID) -> EventLoopFuture<TaskResult?>

    /// Get a result for a given task, user and session
    /// - Parameters:
    ///   - taskID: The task id to fetch the result for
    ///   - userID: The user id to fetch the result for
    ///   - sessionID: The session id to getch the result for
    func getResult(for taskID: Task.ID, by userID: User.ID, sessionID: Sessions.ID) -> EventLoopFuture<TaskResult?>

    /// Get the amount of activities for a given user and subject
    /// - Parameters:
    ///   - user: The user to fetch the history for
    ///   - subjectId: The subject to fetch the history in
    ///   - numberOfWeeks: The number of weeks to fetch
    func getAmountHistory(for user: User, in subjectId: Subject.ID, numberOfWeeks: Int) -> EventLoopFuture<[TaskResult.History]>

    /// Get the amoutn of activity
    /// - Parameters:
    ///   - user: The user to fetch the history for
    ///   - numberOfWeeks: The number of weeks to fetch
    func getAmountHistory(for user: User, numberOfWeeks: Int) -> EventLoopFuture<[TaskResult.History]>

    /// Calculat the what topic to recommend a recap
    /// - Parameters:
    ///   - user: The user to fetch the recommendation for
    ///   - upperBoundDays: The maximum number of days the recommendation is recommended to be recaped on
    ///   - lowerBoundDays: The minimum number of days the recommendation is recommended to be recaped on
    ///   - limit: The maximum amount of recommendations to return
    func recommendedRecap(for user: User.ID, upperBoundDays: Int, lowerBoundDays: Int, limit: Int) -> EventLoopFuture<[RecommendedRecap]>

    /// The results in a exam
    /// - Parameters:
    ///   - ids: The ids of the exam to fetch
    ///   - userID: The user to fetch the results for
    func completionInExamWith(ids: [Exam.ID], userID: User.ID) -> EventLoopFuture<[Exam.Completion]>
    
    /// The total number of tasks completed by all users
    func numberOfCompletedTasks() -> EventLoopFuture<Int>
}
