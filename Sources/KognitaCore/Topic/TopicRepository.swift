//
//  TopicRepository.swift
//  KognitaCore
//
//  Created by Mats Mollestad on 10/04/2019.
//

import Vapor

/// The functionality needed for a repository that handels `Topic`'s
public protocol TopicRepository: DeleteModelRepository {
    /// Return all the `Topic`'s
    func all() throws -> EventLoopFuture<[Topic]>

    /// Return a topic with a given id
    /// - Parameters:
    ///   - id: The id assosiated with the `Topic`
    ///   - error: The error to throw if the `Topic` do not exist
    func find(_ id: Topic.ID, or error: Error) -> EventLoopFuture<Topic>

    /// Creates a `Topic`
    /// - Parameters:
    ///   - content: The data assosiated with the `Topic`
    ///   - user: The user creating the `Topic`
    func create(from content: Topic.Create.Data, by user: User?) throws -> EventLoopFuture<Topic.Create.Response>

    /// Updatedes a `Topic`
    /// - Parameters:
    ///   - id: The id of the topic to update
    ///   - data: The data defining what to update it to
    ///   - user: The user updating the data
    func updateModelWith(id: Int, to data: Topic.Update.Data, by user: User) throws -> EventLoopFuture<Topic.Update.Response>

    /// Returns the topics for a given subject id
    /// - Parameter subjectID: The id of the subject
    func getTopicsWith(subjectID: Subject.ID) -> EventLoopFuture<[Topic]>

    /// Exports all the data in a Topic
    /// - Parameter topic: The topic to export the data for
    func exportTasks(in topic: Topic) throws -> EventLoopFuture<Topic.Export>

    /// Exports all the data in a given subject
    /// - Parameter subject: The subject to export for
    func exportTopics(in subject: Subject) throws -> EventLoopFuture<Subject.Export>

    /// Import topic content into a given subject
    /// - Parameters:
    ///   - content: The topic content to import
    ///   - subjectID: The subject to import it into
    func importContent(from content: Topic.Import, in subjectID: Subject.ID) -> EventLoopFuture<Void>

    /// Import the subtopic content for a gicen topic
    /// - Parameters:
    ///   - content: The subtopic data to import
    ///   - topic: The topic to import it into
    func importContent(from content: Subtopic.Import, in topic: Topic) throws -> EventLoopFuture<Void>

    /// Return more detailed Topic data containing the number of tasks in each topic for a given subject id
    /// - Parameter subjectID: The subject to return the `Topic`s for
    func getTopicsWithTaskCount(withSubjectID subjectID: Subject.ID) throws -> EventLoopFuture<[Topic.WithTaskCount]>

    /// Return the subtopics together with the different topics for a given subject id
    /// - Parameter subjectID: The subject id to get the topics for
    func topicsWithSubtopics(subjectID: Subject.ID) -> EventLoopFuture<[Topic.WithSubtopics]>

    /// Save the different `Topic`s into a subject
    /// - Parameters:
    ///   - topics: The topics to save
    ///   - subjectID: The subject id to save the topics to
    ///   - user: The user wanting to save the topics
    func save(topics: [Topic], forSubjectID subjectID: Subject.ID, user: User) -> EventLoopFuture<Void>

    /// Returns the topic for a given task id
    /// - Parameter taskID: The task id to fetch the topic for
    func topicFor(taskID: Task.ID) -> EventLoopFuture<Topic>
}

public struct TimelyTopic: Codable {
    public let subjectName: String
    public let topicName: String
    public let topicID: Int
    public let numberOfTasks: Int
}

struct TopicTaskCount: Codable {
    let taskCount: Int
    let multipleChoiceTaskCount: Int
}

extension TaskBetaFormat {
    init(task: TaskDatabaseModel, solution: String?) {
        self.init(
            description: task.description,
            question: task.question,
            solution: solution,
            examPaperSemester: nil,
            examPaperYear: nil,
            editedTaskID: nil
        )
    }
}

extension MultipleChoiceTask.Details {
    init(task: Task, choices: [MultipleChoiceTaskChoice], isMultipleSelect: Bool, solutions: [TaskSolution]) {
        self.init(
            id: task.id,
            subtopicID: task.subtopicID,
            description: task.description,
            question: task.question,
            creatorID: task.creatorID,
            exam: task.exam,
            isTestable: task.isTestable,
            isDraft: false,
            createdAt: task.createdAt,
            updatedAt: task.updatedAt,
            deletedAt: task.deletedAt,
            isMultipleSelect: isMultipleSelect,
            choices: choices,
            solutions: solutions
        )
    }
}

extension TypingTask.Details {
    init(task: Task, solutions: [TaskSolution]) {
        self.init(
            id: task.id,
            subtopicID: task.subtopicID,
            description: task.description,
            question: task.question,
            creatorID: task.creatorID,
            exam: task.exam,
            isTestable: task.isTestable,
            createdAt: task.createdAt,
            updatedAt: task.updatedAt,
            deletedAt: task.deletedAt,
            editedTaskID: task.editedTaskID,
            solutions: solutions
        )
    }
}

extension Topic {
    public struct WithTaskCount: Content {
        public let topic: Topic

        public let typingTaskCount: Int
        public let multipleChoiceTaskCount: Int

        public var totalTaskCount: Int { typingTaskCount + multipleChoiceTaskCount }

        public func userLevelZero() -> UserLevel {
            .init(topicID: topic.id, correctScore: 0, maxScore: Double(totalTaskCount))
        }
    }
}
