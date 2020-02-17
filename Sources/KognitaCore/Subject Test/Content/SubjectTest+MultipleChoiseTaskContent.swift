import Vapor

extension SubjectTest {

    public struct MultipleChoiseTaskContent: Content {

        public struct Choise: Content {
            public let id: MultipleChoiseTaskChoise.ID
            public let choise: String
            public let isCorrect: Bool
            public let isSelected: Bool
        }

        public let test: SubjectTest
        public let task: Task
        public let isMultipleSelect: Bool
        public let choises: [Choise]

        public let testTasks: [TestTask]

        init(test: SubjectTest, task: Task, multipleChoiseTask: KognitaCore.MultipleChoiseTask, choises: [MultipleChoiseTaskChoise], selectedChoises: [MultipleChoiseTaskAnswer], testTasks: [SubjectTest.Pivot.Task]) {
            self.test = test
            self.task = task
            self.isMultipleSelect = multipleChoiseTask.isMultipleSelect
            self.choises = choises.compactMap { choise in
                try? Choise(
                    id: choise.requireID(),
                    choise: choise.choise,
                    isCorrect: choise.isCorrect,
                    isSelected: selectedChoises.contains(where: { $0.choiseID == choise.id })
                )
            }
            self.testTasks = testTasks.compactMap { testTask in
                guard let testTaskID = testTask.id else {
                    return nil
                }
                return TestTask(
                    testTaskID: testTaskID,
                    isCurrent: testTask.taskID == task.id
                )
            }
        }
    }
}
