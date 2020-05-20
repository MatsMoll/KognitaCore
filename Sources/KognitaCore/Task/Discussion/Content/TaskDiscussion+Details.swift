import Vapor

extension TaskDiscussion {

    public struct Details: Content {

        public let id: TaskDiscussion.ID
        public let description: String
        public let createdAt: Date?
        public let username: String
        public let newestResponseCreatedAt: Date
    }
}

extension TaskDiscussion.Details: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.id == rhs.id
    }
}

extension Array where Element: Hashable {
    func removingDuplicates() -> [Element] {
        var addedDict = [Element: Bool]()

        return filter {
            addedDict.updateValue(true, forKey: $0) == nil
        }
    }

    mutating func removeDuplicates() {
        self = self.removingDuplicates()
    }
}
