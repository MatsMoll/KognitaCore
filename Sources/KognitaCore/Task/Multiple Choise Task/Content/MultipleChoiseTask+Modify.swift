//extension MultipleChoiseTask {
//
//    public struct ModifyContent {
//        public let task: Task.ModifyContent?
//        public let subject: Subject
//        public let topics: [Topic]
//
//        public let isMultipleSelect: Bool
//        public let choises: [MultipleChoiseTaskChoise.Data]
//
//        public init(task: Task.ModifyContent?, subject: Subject, topics: [Topic], multiple: MultipleChoiseTask?, choises: [MultipleChoiseTaskChoise.Data]) {
//            self.task = task
//            self.subject = subject
//            self.topics = topics
//            self.isMultipleSelect = multiple?.isMultipleSelect ?? false
//            self.choises = choises
//        }
//
//        public init(subject: Subject, topics: [Topic]) {
//            self.task = nil
//            self.isMultipleSelect = false
//            self.choises = []
//            self.subject = subject
//            self.topics = topics
//        }
//    }
//}
