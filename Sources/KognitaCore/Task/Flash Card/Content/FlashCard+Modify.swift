extension FlashCardTask {
    public struct ModifyContent {
        public let task: Task.ModifyContent?
        public let subject: Subject.Overview
        public let topics: [Topic.Response]

        public init(task: Task.ModifyContent?, subject: Subject.Overview, topics: [Topic.Response]) {
            self.task = task
            self.subject = subject
            self.topics = topics
        }

        public init(subject: Subject, topics: [Topic.Response]) {
            self.task = nil
            self.subject = Subject.Overview(subject: subject)
            self.topics = topics
        }
    }
}
