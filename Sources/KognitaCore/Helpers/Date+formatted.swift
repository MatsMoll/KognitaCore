//
//  Date+formatted.swift
//  App
//
//  Created by Mats Mollestad on 02/05/2019.
//

import Foundation

extension Date {
    /// Formats a `Date` into a localized format
    /// - Parameters:
    ///   - dateStyle: The date style to use
    ///   - timeStyle: The time style to use
    /// - Returns: Returns a string that is formated
    public func formatted(dateStyle: DateFormatter.Style = .short, timeStyle: DateFormatter.Style = .short) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = dateStyle
        formatter.timeStyle = timeStyle
        return formatter.string(from: self)
    }
}
