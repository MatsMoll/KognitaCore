
extension Subject {

    public struct ListOverview: Codable {
        public let id: Subject.ID
        public let name: String
        public let description: String
        public let category: String
        public let colorClass: ColorClass
        public let isActive: Bool

        init(subject: Subject, isActive: Bool) {
            self.id = subject.id ?? 0
            self.name = subject.name
            self.description = subject.description
            self.colorClass = subject.colorClass
            self.category = subject.category
            self.isActive = isActive
        }
    }
}
