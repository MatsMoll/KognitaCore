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
        let html = try SwiftSoup.parse(string)
        return try (html.body() ?? html)
            .children()
            .reduce(into: "") { result, node in
                if node.nodeName() == "p" {
                    let inner = try node.html()
                    guard !inner.isEmpty else { return }
                    let newLine: String
                    if result.hasSuffix("\n\n") || result.isEmpty {
                        newLine = ""
                    } else if result.hasSuffix("\n") {
                        newLine = "\n"
                    } else {
                        newLine = "\n\n"
                    }
                    result += "\(newLine)\(inner)"
                } else {
                    result += try "\n\(node.outerHtml())"
                }
        }
    }
}
