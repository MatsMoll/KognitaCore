extension Task {
    public struct PeerWise: Codable {

        public let topicName: String
        public let question: String
        public let solution: String
        public let choises: [MultipleChoiseTaskChoise.Create.Data]
    }
}
