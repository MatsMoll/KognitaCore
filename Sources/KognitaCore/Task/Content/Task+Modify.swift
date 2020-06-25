import Foundation

//extension TaskDatabaseModel {
//    public struct ModifyContent: Codable {
//
//        public let id: Int
//
//        public let creatorID: User.ID?
//
//        /// The topic.id for the topic this task relates to
//        public let subtopicID: Subtopic.ID
//
//        /// Some html that contains extra information about the task if needed
//        public let description: String?
//
//        /// The question needed to answer the task
//        public let question: String
//
//        /// The semester of the exam
//        public let examPaperSemester: ExamSemester?
//
//        /// The year of the exam
//        public let examPaperYear: Int?
//
//        /// If the task can be used for testing
//        public let isTestable: Bool
//
//        /// The id of the new edited task if there exists one
//        public let editedTaskID: Task.ID?
//
//        public let solution: String
//
//        public let deletedAt: Date?
//
//        public var isDeleted: Bool { deletedAt != nil }
//
//        init(task: Task, solution: String) {
//            self.id = task.id ?? 0
//            self.subtopicID = task.subtopicID
//            self.description = task.description
//            self.question = task.question
////            self.examPaperYear = task.examPaperYear
////            self.examPaperSemester = task.examPaperSemester
//            self.isTestable = task.isTestable
//            self.editedTaskID = task.editedTaskID
//            self.solution = solution
//            self.deletedAt = task.deletedAt
//            self.creatorID = task.creatorID
//        }
//    }
//}
