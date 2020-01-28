import Vapor

extension Subject {
    public struct Details: Codable {

        public let subject: Subject
        public let topics: [Topic.UserOverview]
        public let subjectLevel: User.SubjectLevel
        public let isActive: Bool
        public let canPractice: Bool

        public init(subject: Subject, topics: [Topic.WithTaskCount], levels: [User.TopicLevel], isActive: Bool, canPractice: Bool) {
            self.subject = subject

            var topicLevels = [Topic.ID: Topic.UserOverview]()
            for topic in topics {
                topicLevels[topic.topic.id ?? 0] = .init(
                    id: topic.topic.id ?? 0,
                    name: topic.topic.name,
                    numberOfTasks: topic.taskCount,
                    userScore: 0
                )
            }

            var correctScore: Double = 0
            var maxScore: Double = 0

            for level in levels {
                correctScore += level.correctScore
                maxScore += level.maxScore

                if var overview = topicLevels[level.topicID] {
                    overview.userScore += level.correctScore
                    topicLevels[level.topicID] = overview
                }
            }

            self.subjectLevel = User.SubjectLevel(
                subjectID: subject.id ?? 0,
                correctScore: correctScore,
                maxScore: maxScore
            )
            self.topics = topics.compactMap { topicLevels[$0.topic.id ?? 0] }
            self.isActive = isActive
            self.canPractice = canPractice
        }
    }
}
