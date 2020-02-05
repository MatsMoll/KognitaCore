
extension Subject {
    public struct Overview: Codable {
        public let id: Subject.ID
        public let name: String
        public let colorClass: ColorClass

        init(subject: Subject) {
            self.id = subject.id ?? 0
            self.name = subject.name
            self.colorClass = subject.colorClass
        }
    }
}
