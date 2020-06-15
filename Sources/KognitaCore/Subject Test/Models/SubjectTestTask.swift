import FluentPostgreSQL
import FluentSQL
import Vapor

/// A practice session object
extension SubjectTest {
    enum Pivot {
        final class Task: PostgreSQLPivot {

            public typealias Database = PostgreSQLDatabase

            typealias Left = SubjectTest.DatabaseModel
            public typealias Right = KognitaCore.Task

            public static var leftIDKey: LeftIDKey = \.testID
            public static var rightIDKey: RightIDKey = \.taskID

            public static var createdAtKey: TimestampKey? = \.createdAt

            public var id: Int?
            var testID: SubjectTest.ID
            var taskID: KognitaCore.Task.ID

            public var createdAt: Date?

            init(testID: SubjectTest.ID, taskID: Task.ID) {
                self.testID = testID
                self.taskID = taskID
            }
        }
    }
}

extension SubjectTest.Pivot.Task: Migration {

    public static func prepare(on conn: PostgreSQLConnection) -> EventLoopFuture<Void> {
        return PostgreSQLDatabase.create(SubjectTest.Pivot.Task.self, on: conn) { builder in
            try addProperties(to: builder)
            builder.unique(on: \.taskID, \.testID)

            builder.reference(from: \.taskID, to: \Task.id, onUpdate: .cascade, onDelete: .cascade)
            builder.reference(from: \.testID, to: \SubjectTest.DatabaseModel.id, onUpdate: .cascade, onDelete: .cascade)
        }
    }

    public static func revert(on connection: PostgreSQLConnection) -> EventLoopFuture<Void> {
        return PostgreSQLDatabase.delete(SubjectTest.Pivot.Task.self, on: connection)
    }
}

internal protocol SubjectTestTaskRepositoring {
    func create(from content: SubjectTest.Pivot.Task.Create.Data, by user: User?) throws -> EventLoopFuture<SubjectTest.Pivot.Task.Create.Response>
    func updateModelWith(id: Int, to data: SubjectTest.Pivot.Task.Update.Data, by user: User) throws -> EventLoopFuture<SubjectTest.Pivot.Task.Update.Response>
}

extension SubjectTest.Pivot.Task {

    public enum Create {
        public struct Data {
            let testID: SubjectTest.ID
            let taskIDs: [Task.ID]
        }

        public typealias Response = [SubjectTest.Pivot.Task]
    }

    public enum Update {
        public typealias Data = [Task.ID]
        public typealias Response = Void
    }

    struct DatabaseRepository: SubjectTestTaskRepositoring, DatabaseConnectableRepository {

        let conn: DatabaseConnectable

        func create(from content: SubjectTest.Pivot.Task.Create.Data, by user: User?) throws -> EventLoopFuture<[SubjectTest.Pivot.Task]> {
            content.taskIDs.map {
                SubjectTest.Pivot.Task(
                    testID: content.testID,
                    taskID: $0
                )
                .create(on: self.conn)
            }
            .flatten(on: conn)
        }

        func updateModelWith(id: Int, to data: SubjectTest.Pivot.Task.Update.Data, by user: User) throws -> EventLoopFuture<Void> {
            SubjectTest.Pivot.Task
                .query(on: conn)
                .filter(\.testID == id)
                .all()
                .flatMap { (tasks: [SubjectTest.Pivot.Task]) in

                    data.changes(from: tasks.map { $0.taskID })
                        .compactMap { change in

                            switch change {
                            case .insert(let taskID):
                                return SubjectTest.Pivot.Task(
                                    testID: id,
                                    taskID: taskID
                                )
                                    .create(on: self.conn)
                                    .transform(to: ())
                            case .remove(let taskID):
                                return tasks.first(where: { $0.taskID == taskID })?
                                    .delete(on: self.conn)
                            }
                    }
                    .flatten(on: self.conn)
            }
        }
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
