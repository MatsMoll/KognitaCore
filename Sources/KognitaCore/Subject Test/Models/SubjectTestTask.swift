import FluentKit
import Vapor

/// A practice session object
extension SubjectTest {
    enum Pivot {
        final class Task: Model {

            static var schema: String = "SubjectTest_Task"

            @DBID(custom: "id")
            public var id: Int?

            @Parent(key: "testID")
            var test: SubjectTest.DatabaseModel

            @Parent(key: "taskID")
            var task: KognitaCore.TaskDatabaseModel

            @Timestamp(key: "createdAt", on: .create)
            public var createdAt: Date?

            init() {}

            init(testID: SubjectTest.ID, taskID: KognitaContent.Task.ID) {
                self.$test.id = testID
                self.$task.id = taskID
            }
        }
    }
}

extension SubjectTest.Pivot.Task {
    enum Migrations {}
}

extension SubjectTest.Pivot.Task.Migrations {
    struct Create: Migration {

        let schema = SubjectTest.Pivot.Task.schema

        func prepare(on database: Database) -> EventLoopFuture<Void> {
            database.schema(schema)
                .field("id", .uint, .identifier(auto: true))
                .field("testID", .uint, .required, .references(SubjectTest.DatabaseModel.schema, .id, onDelete: .cascade, onUpdate: .cascade))
                .field("taskID", .uint, .required, .references(TaskDatabaseModel.schema, .id, onDelete: .cascade, onUpdate: .cascade))
                .field("createdAt", .date, .required)
                .unique(on: "taskID", "testID")
                .create()
        }

        func revert(on database: Database) -> EventLoopFuture<Void> {
            database.schema(schema).delete()
        }
    }
}

extension SubjectTest.Pivot.Task {

    enum Create {
        struct Data {
            let testID: SubjectTest.ID
            let taskIDs: [KognitaContent.Task.ID]
        }

        typealias Response = [SubjectTest.Pivot.Task]
    }

    enum Update {
        typealias Data = [KognitaContent.Task.ID]
        typealias Response = Void
    }
}

extension Array where Element: Hashable {

    enum Change {
        case insert(Element)
        case remove(Element)
    }

    func changes<T: BidirectionalCollection>(from collection: T) -> [Change] where T.Element == Element {
        difference(from: collection)
            .reduce(into: [Element: Int]()) { changes, change in
            switch change {
            case .insert(_, let element, _): changes[element] = (changes[element] ?? 0) + 1
            case .remove(_, let element, _): changes[element] = (changes[element] ?? 0) - 1
            }
        }.compactMap { taskID, value in
            if value == 0 {
                return nil
            } else if value > 0 {
                return .insert(taskID)
            } else {
                return .remove(taskID)
            }
        }
    }
}
