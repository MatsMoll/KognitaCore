import Vapor

extension TaskDiscussion.Pivot.Response {

    public final class Active: Content {

        public let userID: User.ID
        public var visitedRecently: Date?
    }

    public func saveRecentlyDate(on taskDiscussion: TaskDiscussion.Pivot.Response.Active) -> TaskDiscussion.Pivot.Response.Active {
        taskDiscussion.visitedRecently = Date()

    }
}



