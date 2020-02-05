
extension MultipleChoiseTask {

    public struct ModifyContent {
        public let task: Task.ModifyContent?
        public let subject: Subject.Overview
        public let topics: [Topic.Response]

        public let isMultipleSelect: Bool
        public let choises: [MultipleChoiseTaskChoise.Data]

        public init(task: Task.ModifyContent?, subject: Subject.Overview, topics: [Topic.Response], multiple: MultipleChoiseTask?, choises: [MultipleChoiseTaskChoise.Data]) {
            self.task = task
            self.subject = subject
            self.topics = topics
            self.isMultipleSelect = multiple?.isMultipleSelect ?? false
            self.choises = choises
        }

        public init(subject: Subject, topics: [Topic.Response]) {
            self.task = nil
            self.isMultipleSelect = false
            self.choises = []
            self.subject = .init(subject: subject)
            self.topics = topics
        }
    }
}
