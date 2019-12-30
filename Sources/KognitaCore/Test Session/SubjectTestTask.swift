import FluentPostgreSQL
import FluentSQL
import Vapor

/// A practice session object
extension SubjectTest {
    public enum Pivot {
        public final class Task: PostgreSQLPivot {

            public typealias Left = SubjectTest
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

    public static func prepare(on conn: PostgreSQLConnection) -> Future<Void> {
        return PostgreSQLDatabase.create(SubjectTest.Pivot.Task.self, on: conn) { builder in
            try addProperties(to: builder)
            builder.unique(on: \.taskID, \.testID)

            builder.reference(from: \.taskID, to: \Task.id,         onUpdate: .cascade, onDelete: .cascade)
            builder.reference(from: \.testID, to: \SubjectTest.id,  onUpdate: .cascade, onDelete: .cascade)
        }
    }

    public static func revert(on connection: PostgreSQLConnection) -> Future<Void> {
        return PostgreSQLDatabase.delete(SubjectTest.Pivot.Task.self, on: connection)
    }
}


public protocol SubjectTestTaskRepositoring:
    CreateModelRepository,
    UpdateModelRepository
    where
    CreateData      == SubjectTest.Pivot.Task.Create.Data,
    CreateResponse  == SubjectTest.Pivot.Task.Create.Response,
    UpdateData      == SubjectTest.Pivot.Task.Update.Data,
    UpdateResponse  == SubjectTest.Pivot.Task.Update.Response,
    Model           == SubjectTest
{}


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


    @available(OSX 10.15, *)
    struct Repository: SubjectTestTaskRepositoring {

        static func create(from content: SubjectTest.Pivot.Task.Create.Data, by user: User?, on conn: DatabaseConnectable) throws -> EventLoopFuture<[SubjectTest.Pivot.Task]> {
            content.taskIDs.map {
                SubjectTest.Pivot.Task(
                    testID: content.testID,
                    taskID: $0
                )
                .create(on: conn)
            }
            .flatten(on: conn)
        }

        static func update(model: SubjectTest, to data: SubjectTest.Pivot.Task.Update.Data, by user: User, on conn: DatabaseConnectable) throws -> EventLoopFuture<Void> {
            try SubjectTest.Pivot.Task
                .query(on: conn)
                .filter(\.testID == model.requireID())
                .all()
                .flatMap { (tasks: [SubjectTest.Pivot.Task]) in

                    try data.changes(from: tasks.map { $0.taskID })
                        .compactMap { (change: Array<Task.ID>.Change) in

                            switch change {
                            case .insert(let taskID):
                                return try SubjectTest.Pivot.Task(
                                    testID: model.requireID(),
                                    taskID: taskID
                                )
                                    .create(on: conn)
                                    .transform(to: ())
                            case .remove(let taskID):
                                return tasks.first(where: { $0.taskID == taskID })?
                                    .delete(on: conn)
                            }
                    }
                    .flatten(on: conn)
            }
        }
    }
}

extension Array where Element : Hashable {

    enum Change {
        case insert(Element)
        case remove(Element)
    }

    @available(OSX 10.15, *)
    func changes<T: BidirectionalCollection>(from collection: T) -> [Change] where T.Element == Element {
        difference(from: collection)
            .reduce(into: Dictionary<Element, Int>()) { changes, change in
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
