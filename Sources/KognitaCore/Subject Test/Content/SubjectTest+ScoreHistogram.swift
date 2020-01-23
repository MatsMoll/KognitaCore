import Vapor

extension SubjectTest {
    public struct ScoreHistogram: Content {

        public struct Score: Content {
            public let score: Int
            public let amount: Int
            public let percentage: Double
        }

        public let scores: [Score]
    }
}
