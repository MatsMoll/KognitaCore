import Vapor

extension Subject {
    public struct Details: Codable {

        public let subject: Subject
        public let topics: [Topic.UserOverview]
        public let subjectLevel: User.SubjectLevel
        public let openTest: SubjectTest.OverviewResponse?
        public let numberOfTasks: Int
        public let isActive: Bool
        public let canPractice: Bool
        public let isModerator: Bool

        public init(subject: Subject, topics: [Topic.WithTaskCount], levels: [User.TopicLevel], isActive: Bool, canPractice: Bool, isModerator: Bool, openTest: SubjectTest.OverviewResponse?) {
            self.subject = subject

            var topicLevels = [Topic.ID: Topic.UserOverview]()
            var numberOfTasks = 0
            for topic in topics {
                numberOfTasks += topic.taskCount
                topicLevels[topic.topic.id ?? 0] = .init(
                    id: topic.topic.id ?? 0,
                    name: topic.topic.name,
                    numberOfTasks: topic.taskCount,
                    userLevel: levels.first(where: { $0.topicID == topic.topic.id }) ?? User.TopicLevel(topicID: 0, correctScore: 0, maxScore: 1)
                )
            }

            var correctScore: Double = 0
            var maxScore: Double = 0

            for level in levels {
                correctScore += level.correctScore
                maxScore += level.maxScore
            }

            self.subjectLevel = User.SubjectLevel(
                subjectID: subject.id ?? 0,
                correctScore: correctScore,
                maxScore: max(maxScore, Double(numberOfTasks))
            )
            self.topics = topics.compactMap { topicLevels[$0.topic.id ?? 0] }
            self.isActive = isActive
            self.canPractice = canPractice
            self.numberOfTasks = numberOfTasks
            self.isModerator = isModerator
            self.openTest = openTest
        }
    }
}
