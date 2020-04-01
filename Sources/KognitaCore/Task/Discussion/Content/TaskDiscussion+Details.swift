import Vapor

extension TaskDiscussion {

    public struct Details: Content {

        public let id: TaskDiscussion.ID
        public let description: String
        public let createdAt: Date?
        public let username: String
    }
}

extension TaskDiscussion.Details: Hashable {}


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


