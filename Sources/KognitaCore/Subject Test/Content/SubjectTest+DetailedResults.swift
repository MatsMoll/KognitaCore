import Vapor

extension SubjectTest {

    public struct DetailedResult: Content {
        let testID: SubjectTest.ID
        let testTitle: String
        let maxScore: Double
        let results: [UserStats]
    }

    public struct UserStats: Codable {
        let timePracticed: TimeInterval
        let medianTimePerTask: TimeInterval
        let numberOfTaskExecuted: Int
        let testScore: Double
        let userID: User.ID
    }
}
