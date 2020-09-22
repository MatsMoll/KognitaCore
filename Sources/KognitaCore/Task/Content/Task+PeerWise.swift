public struct TaskPeerWise: Codable {

    public let topicName: String
    public let question: String
    public let solution: String
    public let choises: [MultipleChoiceTaskChoice.Create.Data]
}
