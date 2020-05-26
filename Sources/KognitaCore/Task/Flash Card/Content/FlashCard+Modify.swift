extension FlashCardTask {
    public struct ModifyContent {
        public let task: Task.ModifyContent?
        public let subject: Subject
        public let topics: [Topic]

        public init(task: Task.ModifyContent?, subject: Subject, topics: [Topic]) {
            self.task = task
            self.subject = subject
            self.topics = topics
        }

        public init(subject: Subject, topics: [Topic]) {
            self.task = nil
            self.subject = subject
            self.topics = topics
        }
    }
}
