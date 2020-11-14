import SwiftSoup

public enum CleaningError: Error {
    case noStringLeft
}

extension String {
    func cleanXSS(whitelist: Whitelist) throws -> String {

        // This is done since the new line will be removed when cleaning a html document
        let noNewLine = self.split(separator: "\n").reduce("") { $0 + "<p>" + $1 + "</p>" }

        guard let string = try SwiftSoup.clean(noNewLine, whitelist) else {
            throw CleaningError.noStringLeft
        }
        return string
            .replacingOccurrences(of: "</p>\n<p>", with: "\n\n")
            .replacingOccurrences(of: "</p>", with: "")
            .replacingOccurrences(of: "<p>", with: "")
    }
}
