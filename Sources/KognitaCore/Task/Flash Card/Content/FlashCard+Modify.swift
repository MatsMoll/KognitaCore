extension FlashCardTask {
    public struct ModifyContent {
        public let task: Task.ModifyContent?
        public let subject: Subject.Overview

        public init(task: Task.ModifyContent?, subject: Subject.Overview) {
            self.task = task
            self.subject = subject
        }

        public init(subject: Subject.Overview) {
            self.task = nil
            self.subject = subject
        }
    }
}
