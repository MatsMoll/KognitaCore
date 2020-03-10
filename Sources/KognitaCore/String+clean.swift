import SwiftSoup

public enum CleaningError: Error {
    case noStringLeft
}

extension String {
    func cleanXSS(whitelist: Whitelist) throws -> String {
        guard let string = try SwiftSoup.clean(self, whitelist) else {
            throw CleaningError.noStringLeft
        }
        return string
    }
}
