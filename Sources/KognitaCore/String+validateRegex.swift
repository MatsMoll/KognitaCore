//
//  String+evaluateRegex.swift
//  App
//
//  Created by Mats Mollestad on 07/01/2019.
//

import Vapor

extension String {

    /// Validates a string with a regex expression
    ///
    /// - Parameter regex:
    ///     The regex to use when validating
    ///
    /// - Throws:
    ///     If invalid regex
    ///
    /// - Returns:
    ///     True or false based on the result
    public func validateWith(regex: String) throws -> Bool {
        guard let regexValidator = try? NSRegularExpression(pattern: regex) else {
            throw Abort(.internalServerError, reason: "Misformed regex")
        }
        let range = NSRange(startIndex..., in: self)
        guard let result = regexValidator.firstMatch(in: self, range: range) else {
            return false
        }
        return result.range == range
    }
}
