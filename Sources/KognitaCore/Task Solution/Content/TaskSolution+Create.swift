import Vapor

extension TaskSolution {
    public enum Create {
        public struct Data {
            let solution: String
            let presentUser: Bool
            var taskID: Task.ID
        }
        public struct Response: Content {}
    }
}
