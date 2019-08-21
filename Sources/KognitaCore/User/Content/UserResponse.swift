//
//  UserResponse.swift
//  KognitaCore
//
//  Created by Mats Mollestad on 11/04/2019.
//

import Vapor

/// Public representation of user data.
public struct UserResponse: Content {
    /// User's unique identifier.
    /// Not optional since we only return users that exist in the DB.
    public let id: Int

    /// User's full name.
    public let name: String

    /// User's email address.
    public let email: String

    /// The User's registration date
    public let registrationDate: Date
}
