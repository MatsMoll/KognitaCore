//
//  UserRepository.swift
//  KognitaCore
//
//  Created by Mats Mollestad on 11/04/2019.
//

import Crypto
import Vapor
import FluentKit

extension EventLoopFuture where Value: ContentConvertable {
    /// Converts a data type from it's database model to it's KognitaModels representation
    /// - Returns: The public data model
    func content() -> EventLoopFuture<Value.ResponseModel> {
        flatMapThrowing { try $0.content() }
    }
}

public protocol UserRepresentable {
    var email: String { get }
    var username: String { get }
    var usedPassword: String? { get }
    var isEmailVerified: Bool { get }
    var pictureUrl: String? { get }
}

public protocol TokenConfig {
    var token: String { get }
    var expiresAt: Date { get }
}

/// A protocol defining the needed functionality for a repository handeling a `User`
public protocol UserRepository: ResetPasswordRepositoring {

    /// Finds the user given an id
    /// - Parameter id: The id of the user
    /// - Returns: A future user if it exists
    func find(_ id: User.ID) -> EventLoopFuture<User?>

    /// Finds the user given an id
    /// - Parameters:
    ///   - id: The id of the user
    ///   - error: An error if the user do not exist
    /// - Returns: A future user
    func find(_ id: User.ID, or error: Error) -> EventLoopFuture<User>

    /// Creates a `User`
    /// - Parameters:
    ///   - content: The content defining the new user
    func create(from content: User.Create.Data) throws -> EventLoopFuture<User>

    /// Creates a `User` based on a more generalized data structure
    /// NB: This will skip some verification
    /// - Parameter user: The data needed to create the user in the database
    /// - Parameter handleDuplicateSilently: If if should throw an error if there is an duplicate user
    func unsafeCreate(_ user: UserRepresentable, handleDuplicateSilently: Bool) throws -> EventLoopFuture<User>

    /// Login using a token based method
    /// - Parameter user: The user to login as
    /// - Returns: A future `User.Login.Token`
    func login(with user: User) throws -> EventLoopFuture<User.Login.Token>

    /// Login using a feide token
    /// - Parameter tokenConfig: The token assosiated with the login
    /// - Parameter userID: The id of the user assosiated with the token
    /// - Returns: A future `User.Login.Token`
    func loginWith(feide tokenConfig: TokenConfig, for userID: User.ID) throws -> EventLoopFuture<User.Login.Token>

    /// Saves a users feide login grant, as it will be used on logout
    /// - Parameters:
    ///   - grant: The grant
    ///   - userID: The id of the user assosiated with the grant
    func saveFeide(grant: Feide.Grant, for userID: User.ID) -> EventLoopFuture<Void>

    /// finds the latest grant if any
    /// - Parameter userID: The user id assosiated with the grant
    func latestFeideGrant(for userID: User.ID) -> EventLoopFuture<Feide.Grant?>

    func latestFeideToken(for userID: User.ID) -> EventLoopFuture<User.Login.Token?>

    /// Marks a Feide Grant as outdated
    /// - Parameters:
    ///   - grant: The grant to mark
    ///   - userID: The id of the user requesting the mark
    func markAsOutdated(grant: Feide.Grant, for userID: User.ID) -> EventLoopFuture<Void>

    /// Logs a user login
    /// - Parameters:
    ///   - user: The user to log
    ///   - ipAddress: The ip address if it exists
    func logLogin(for user: User, with ipAddress: String?) -> EventLoopFuture<Void>

    /// Verify that the password is correct for a given email
    /// - Parameters:
    ///   - email: The email assosiated with an `User`
    ///   - password: The password to verify
    /// - Returns: A future user if the email password combo was correct
    func verify(email: String, with password: String) -> EventLoopFuture<User?>

    /// Returns a user for a fiven login token
    /// - Parameter token: The token assosiated with the user
    /// - Returns: A future `User` if correct
    func user(with token: String) -> EventLoopFuture<User?>

    /// Returns a user with a given email
    /// - Parameter email: The email to filter on
    func first(with email: String) -> EventLoopFuture<User?>

    /// Checks if a user is a moderator in a subject
    /// - Parameters:
    ///   - user: The user to check
    ///   - subjectID: The subject id
    /// - Returns: A future `Bool` indicating if the user is a moderator
    func isModerator(user: User, subjectID: Subject.ID) -> EventLoopFuture<Bool>

    /// Checks if a user is a moderator in a subtopic
    /// - Parameters:
    ///   - user: The user to check
    ///   - subtopicID: The subtopicid
    /// - Returns: A future `Bool` indicating if the user is a moderator
    func isModerator(user: User, subtopicID: Subtopic.ID) throws -> EventLoopFuture<Bool>

    /// Checks if a user is a moderator in a task
    /// - Parameters:
    ///   - user: The user to check
    ///   - taskID: The task id
    /// - Returns: A future `Bool` indicating if the user is a moderator
    func isModerator(user: User, taskID: Task.ID) -> EventLoopFuture<Bool>

    /// Checks if a user is a moderator in a topic id
    /// - Parameters:
    ///   - user: The user to check
    ///   - topicID: The topic id
    /// - Returns: A future `Bool` indicating if the user is a moderator
    func isModerator(user: User, topicID: Topic.ID) throws -> EventLoopFuture<Bool>

    /// Checks if a user can practice in a given subject
    /// - Parameters:
    ///   - user: The user to check
    ///   - subjectID: The subject id
    /// - Returns: A future `Bool` indicating if the user is can practice
    func canPractice(user: User, subjectID: Subject.ID) -> EventLoopFuture<Bool>

    /// Verify the email for a given user
    /// - Parameters:
    ///   - user: The user to verify
    ///   - token: The token
    func verify(user: User, with token: User.VerifyEmail.Token) -> EventLoopFuture<Void>

    /// Returns te verify token for a given user
    /// - Parameter userID: The id assosiated with the `User`
    func verifyToken(for userID: User.ID) -> EventLoopFuture<User.VerifyEmail.Token>
    
    func numberOfUsers() -> EventLoopFuture<Int>
}
