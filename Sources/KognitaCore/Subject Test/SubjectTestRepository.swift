import FluentSQL
import Vapor

/// The functionality needed for handeling subject tests
public protocol SubjectTestRepositoring: DeleteModelRepository {

    /// Finds a subject test
    /// - Parameters:
    ///   - id: The id of the subject test
    ///   - error: The error to throw if the id do not exist
    func find(_ id: SubjectTest.ID, or error: Error) -> EventLoopFuture<SubjectTest>

    /// Creates a subject test
    /// - Parameters:
    ///   - content: The data defining the subject test
    ///   - user: The user creating the test
    func create(from content: SubjectTest.Create.Data, by user: User?) throws -> EventLoopFuture<SubjectTest.Create.Response>

    func updateModelWith(id: Int, to data: SubjectTest.Update.Data, by user: User) throws -> EventLoopFuture<SubjectTest.Update.Response>

    /// Opens a test so users can enter
    /// - Parameters:
    ///   - test: The test to open
    ///   - user: The user that opens the test
    ///   - conn: The database connection
    /// - Returns: A future that contains the opend test
    func open(test: SubjectTest, by user: User) throws -> EventLoopFuture<SubjectTest>

    /// A user enters a test in order to submit answers etc
    /// - Parameters:
    ///   - test: The test to enter
    ///   - request: The needed metadata to enter the test
    ///   - user: The user that enters the test
    ///   - conn: The database connection
    /// - Returns: A `TestSession` for the user
    func enter(test: SubjectTest, with request: SubjectTest.Enter.Request, by user: User) -> EventLoopFuture<TestSession>

    /// Retrive data about the test
    /// - Parameters:
    ///   - test: The test to get the status for
    ///   - user: The user requesting the data
    ///   - conn: The database connection
    /// - Returns: A `SubjectTest.CompletionStatus` for a test
    func userCompletionStatus(in test: SubjectTest, user: User) throws -> EventLoopFuture<SubjectTest.CompletionStatus>

    /// Fetches the task and it's metadata
    /// - Parameters:
    ///   - id: The id of the task to fetch
    ///   - session: The test session
    ///   - user: The user to fetch the data for
    ///   - conn: The database connection
    /// - Returns: The data needed to present a task
    func taskWith(id: Int, in session: TestSessionRepresentable, for user: User) throws -> EventLoopFuture<SubjectTest.MultipleChoiseTaskContent>

    /// Fetches the general results on a test
    /// - Parameters:
    ///   - test: The test to fetch the data for
    ///   - user: The user requesting the data
    ///   - conn: The database connection
    /// - Returns: The results of the test
    func results(for test: SubjectTest, user: User) throws -> EventLoopFuture<SubjectTest.Results>

    /// Returns the tests that a user can enter in
    /// - Parameter user: The user to find the tests for
    /// - Parameter conn: The database connection
    func currentlyOpenTest(for user: User) throws -> EventLoopFuture<SubjectTest.UserOverview?>

    /// Returns a list of all the different tests in a subject
    /// - Parameter subject: The subject the tests is for
    /// - Parameter user: The user that requests the tests
    /// - Parameter conn: The database connectino
    func all(in subject: Subject, for user: User) throws -> EventLoopFuture<[SubjectTest]>

    /// Returns a test response for a given id
    /// - Parameters:
    ///   - id: The id of the test
    ///   - user: The user requestiong the test
    ///   - conn: The database connection
    func taskIDsFor(testID id: SubjectTest.ID) throws -> EventLoopFuture<[Task.ID]>

    /// The first task id for the test
    /// - Parameter testID: The id assosiated with the test
    func firstTaskID(testID: SubjectTest.ID) throws -> EventLoopFuture<Int?>

    /// Ends the `SubjectTest`
    /// - Parameters:
    ///   - test: The test to end
    ///   - user: The user ending the test
    func end(test: SubjectTest, by user: User) throws -> EventLoopFuture<Void>

    /// Returns the histogram data for the differnet scores in a test
    /// - Parameters:
    ///   - test: The test to return the data for
    ///   - user: The user requesting the data
    func scoreHistogram(for test: SubjectTest, user: User) throws -> EventLoopFuture<SubjectTest.ScoreHistogram>

    /// Returns a open test in a subject
    /// - Parameters:
    ///   - subject: The subject to get retrive the tests for
    ///   - user: The user requesting the data
    func currentlyOpenTest(in subject: Subject, user: User) throws -> EventLoopFuture<SubjectTest.UserOverview?>

    /// Checks if a test is open
    /// - Parameter testID: The id assosiated with the test
    func isOpen(testID: SubjectTest.ID) -> EventLoopFuture<Bool>

    /// Returns a detailed result of all the users in a test
    /// - Parameters:
    ///   - test: The test to return the data for
    ///   - maxScore: The maximum score in the test
    ///   - user: The user re question the test
    func detailedUserResults(for test: SubjectTest, maxScore: Double, user: User) throws -> EventLoopFuture<[SubjectTest.UserResult]>

    /// Returns some stats for the differnet tests in a subject
    /// - Parameter subject: The subject to return the stats for
    func stats(for subject: Subject) throws -> EventLoopFuture<[SubjectTest.DetailedResult]>
}

enum SortDirection {
    case acending
    case decending
}

extension Array {
    func sorted<T: Comparable>(by keyPath: KeyPath<Element, T>, direction: SortDirection = .acending) -> [Element] {
        let sortFunction: (Element, Element) -> Bool = direction == .acending ? { $0[keyPath: keyPath] > $1[keyPath: keyPath] } : { $0[keyPath: keyPath] < $1[keyPath: keyPath] }
        return sorted(by: sortFunction)
    }
}

//extension SubjectTest.MultipleChoiseTaskContent {
//    init(test: SubjectTest, task: Task, multipleChoiseTask: KognitaCore.MultipleChoiseTask, choises: [MultipleChoiseTaskChoise], selectedChoises: [MultipleChoiseTaskAnswer], testTasks: [SubjectTest.Pivot.Task]) {
//        self.init(
//            test: test,
//            task: MultipleChoiceTask(task: task, multipleChoiceTask: multipleChoiseTask),
//            choises: choises.compactMap { choise in
//                try? Choise(
//                    id: choise.requireID(),
//                    choise: choise.choise,
//                    isCorrect: choise.isCorrect,
//                    isSelected: selectedChoises.contains(where: { $0.choiseID == choise.id })
//                )
//            },
//            testTasks: testTasks.compactMap { testTask in
//                guard let testTaskID = testTask.id else {
//                    return nil
//                }
//                return SubjectTest.AssignedTask(
//                    testTaskID: testTaskID,
//                    isCurrent: testTask.taskID == task.id
//                )
//            }
//        )
//    }
//}
