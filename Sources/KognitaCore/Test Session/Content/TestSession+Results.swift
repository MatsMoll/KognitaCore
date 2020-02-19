import Vapor


extension TestSession {

    public struct Results: Content {

        public struct Task: Content {
            public let question: String
            public let score: Double
        }

        public struct Topic: Content {
            public let name: String
            public let taskResults: [Task]

            public let score: Double
            public let maximumScore: Double

            public var scoreProsentage: Double {
                guard maximumScore != 0 else { return 0 }
                return score / maximumScore
            }

            public var readableScoreProsentage: Double {
                scoreProsentage * 100
            }

            init(name: String, taskResults: [Task]) {
                self.name = name
                self.taskResults = taskResults

                self.score = taskResults.reduce(0) { $0 + $1.score }
                self.maximumScore = Double(taskResults.count)
            }
        }

        public let testTitle: String
        public let executedAt: Date
        public let shouldPresentDetails: Bool
        public let topicResults: [Topic]
        public let expectedScore: Int?

        public let score: Double
        public let maximumScore: Double

        public var scorePercentage: Double {
            guard maximumScore != 0 else { return 0 }
            return score / maximumScore
        }

        init(testTitle: String, executedAt: Date, shouldPresentDetails: Bool, topicResults: [Topic], expectedScore: Int?) {
            self.testTitle = testTitle
            self.executedAt = executedAt
            self.shouldPresentDetails = shouldPresentDetails
            self.topicResults = topicResults
            self.score = topicResults.reduce(0) { $0 + $1.score }
            self.maximumScore = topicResults.reduce(0) { $0 + $1.maximumScore }
            self.expectedScore = expectedScore
        }
    }
}

