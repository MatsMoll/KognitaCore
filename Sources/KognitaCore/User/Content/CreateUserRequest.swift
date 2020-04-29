//
//  CreateUserRequest.swift
//  KognitaCore
//
//  Created by Mats Mollestad on 11/04/2019.
//

import Vapor

extension User {

    public enum Create {
        /// Data required to create a user.
        public struct Data: Content {

            /// User's full name.
            public let username: String

            /// User's email address.
            public let email: String

            /// User's desired password.
            public let password: String

            /// User's password repeated to ensure they typed it correctly.
            public let verifyPassword: String

            /// If the terms is accepted
            public let acceptedTermsInput: String

            /// If the terms is accepted
            public var acceptedTerms: Bool { return acceptedTermsInput == "on" }
        }

        public typealias Response = User.Response
    }

    public enum Edit {

        public struct Data: Content {

            /// User's full name.
            public let username: String

            /// User's desired password.
            public let password: String

            /// User's password repeated to ensure they typed it correctly.
            public let verifyPassword: String
        }

        public typealias Response = User.Response
    }
}
