//
//  SQLSelectBuilder+extension.swift
//  KognitaCore
//
//  Created by Mats Mollestad on 14/11/2020.
//

import FluentSQL
import Vapor

enum PostgreSQLDatePart: String {
    case year
    case day
    case week
}

extension SQLSelectBuilder {
    func column<T: Model, Value>(_ path: KeyPath<T, FieldProperty<T, Value>>) -> Self {
        self.column(table: T.schemaOrAlias, column: T()[keyPath: path].key.description)
    }

    func column<T: Model, Value>(_ path: KeyPath<T, IDProperty<T, Value>>) -> Self {
        self.column(table: T.schemaOrAlias, column: T()[keyPath: path].key.description)
    }

    func column<T: Model, Value>(_ path: KeyPath<T, OptionalFieldProperty<T, Value>>) -> Self {
        self.column(table: T.schemaOrAlias, column: T()[keyPath: path].key.description)
    }

    func column<T: Model, Value>(_ path: KeyPath<T, FieldProperty<T, Value>>, as identifier: String) -> Self {
        return self.column(SQLAlias(SQLColumn(T()[keyPath: path].key.description, table: T.schemaOrAlias), as: SQLIdentifier(identifier)))
    }

    func column<T: Model, Value>(_ path: KeyPath<T, OptionalFieldProperty<T, Value>>, as identifier: String) -> Self {
        return self.column(SQLAlias(SQLColumn(T()[keyPath: path].key.description, table: T.schemaOrAlias), as: SQLIdentifier(identifier)))
    }

    func column<T: Model, Format: TimestampFormat>(_ path: KeyPath<T, TimestampProperty<T, Format>>) -> Self {
        return self.column(SQLColumn(T()[keyPath: path].$timestamp.key.description, table: T.schemaOrAlias))
    }

    func column<T: Model, Format: TimestampFormat>(_ path: KeyPath<T, TimestampProperty<T, Format>>, as identifier: String) -> Self {
        return self.column(SQLAlias(SQLColumn(T()[keyPath: path].$timestamp.key.description, table: T.schemaOrAlias), as: SQLIdentifier(identifier)))
    }

    func column<T: Model, Value>(_ path: KeyPath<T, IDProperty<T, Value>>, as identifier: String) -> Self {
        return self.column(SQLAlias(SQLColumn(T()[keyPath: path].key.description, table: T.schemaOrAlias), as: SQLIdentifier(identifier)))
    }

    func count<T: Model, Value>(_ path: KeyPath<T, IDProperty<T, Value>>, as identifier: String) -> Self {
        return self.column(SQLAlias(SQLFunction("COUNT", args: SQLColumn(T()[keyPath: path].key.description, table: T.schemaOrAlias)), as: SQLIdentifier(identifier)))
    }

    func sum<T: Model, Value>(_ path: KeyPath<T, IDProperty<T, Value>>, as identifier: String) -> Self {
        return self.column(SQLAlias(SQLFunction("SUM", args: SQLColumn(T()[keyPath: path].key.description, table: T.schemaOrAlias)), as: SQLIdentifier(identifier)))
    }

    func sum<T: Model, Value>(_ path: KeyPath<T, FieldProperty<T, Value>>, as identifier: String) -> Self {
        return self.column(SQLAlias(SQLFunction("SUM", args: SQLColumn(T()[keyPath: path].key.description, table: T.schemaOrAlias)), as: SQLIdentifier(identifier)))
    }

    func date<T: Model, Format: TimestampFormat>(part: PostgreSQLDatePart, from path: KeyPath<T, TimestampProperty<T, Format>>, as identifier: String) -> Self {
        return self.column(SQLAlias(SQLFunction("date_part", args: [SQLQueryString("'\(part.rawValue)'"), SQLColumn(T()[keyPath: path].$timestamp.key.description, table: T.schemaOrAlias)]), as: SQLIdentifier(identifier)))
    }

    func groupBy<T: Model, Value>(_ path: KeyPath<T, FieldProperty<T, Value>>) -> Self {
        self.groupBy(SQLColumn(T()[keyPath: path].key.description, table: T.schemaOrAlias))
    }

    func groupBy<T: Model, Value>(_ path: KeyPath<T, OptionalFieldProperty<T, Value>>) -> Self {
        self.groupBy(SQLColumn(T()[keyPath: path].key.description, table: T.schemaOrAlias))
    }

    func groupBy<T: Model, Value>(_ path: KeyPath<T, IDProperty<T, Value>>) -> Self {
        self.groupBy(SQLColumn(T()[keyPath: path].key.description, table: T.schemaOrAlias))
    }

    func join<From: Model, To: Model, IDValue>(from: KeyPath<From, FieldProperty<From, IDValue>>, to path: KeyPath<To, FieldProperty<To, IDValue>>, method: SQLJoinMethod = .inner) -> Self {
        self.join(To.schemaOrAlias, method: method, on: "\"\(From.schemaOrAlias)\".\"\(From()[keyPath: from].key.description)\"=\"\(To.schemaOrAlias)\".\"\(To()[keyPath: path].key.description)\"")
    }

    func join<From: Model, To: Model, IDValue>(from: KeyPath<From, OptionalFieldProperty<From, IDValue>>, to path: KeyPath<To, FieldProperty<To, IDValue>>, method: SQLJoinMethod = .inner) -> Self {
        self.join(To.schemaOrAlias, method: method, on: "\"\(From.schemaOrAlias)\".\"\(From()[keyPath: from].key.description)\"=\"\(To.schemaOrAlias)\".\"\(To()[keyPath: path].key.description)\"")
    }

    func join<From: Model, To: Model, IDValue>(from: KeyPath<From, OptionalFieldProperty<From, IDValue>>, to path: KeyPath<To, OptionalFieldProperty<To, IDValue>>, method: SQLJoinMethod = .inner) -> Self {
        self.join(To.schemaOrAlias, method: method, on: "\"\(From.schemaOrAlias)\".\"\(From()[keyPath: from].key.description)\"=\"\(To.schemaOrAlias)\".\"\(To()[keyPath: path].key.description)\"")
    }

    func join<From: Model, To: Model, IDValue>(from: KeyPath<From, OptionalFieldProperty<From, IDValue>>, to path: KeyPath<To, IDProperty<To, IDValue>>, method: SQLJoinMethod = .inner) -> Self {
        self.join(To.schemaOrAlias, method: method, on: "\"\(From.schemaOrAlias)\".\"\(From()[keyPath: from].key.description)\"=\"\(To.schemaOrAlias)\".\"\(To()[keyPath: path].key.description)\"")
    }

    func join<From: Model, To: Model, IDValue>(from: KeyPath<From, IDProperty<From, IDValue>>, to path: KeyPath<To, OptionalFieldProperty<To, IDValue>>, method: SQLJoinMethod = .inner) -> Self {
        self.join(To.schemaOrAlias, method: method, on: "\"\(From.schemaOrAlias)\".\"\(From()[keyPath: from].key.description)\"=\"\(To.schemaOrAlias)\".\"\(To()[keyPath: path].key.description)\"")
    }

    func join<From: Model, To: Model, IDValue>(from: KeyPath<From, IDProperty<From, IDValue>>, to path: KeyPath<To, IDProperty<To, IDValue>>, method: SQLJoinMethod = .inner) -> Self {
        self.join(To.schemaOrAlias, method: method, on: "\"\(From.schemaOrAlias)\".\"\(From()[keyPath: from].key.description)\"=\"\(To.schemaOrAlias)\".\"\(To()[keyPath: path].key.description)\"")
    }

    func join<From: Model, To: Model, IDValue>(from: KeyPath<From, FieldProperty<From, IDValue>>, to path: KeyPath<To, IDProperty<To, IDValue>>, method: SQLJoinMethod = .inner) -> Self {
        self.join(To.schemaOrAlias, method: method, on: "\"\(From.schemaOrAlias)\".\"\(From()[keyPath: from].key.description)\"=\"\(To.schemaOrAlias)\".\"\(To()[keyPath: path].key.description)\"")
    }

    func join<From: Model, To: Model, IDValue>(from: KeyPath<From, IDProperty<From, IDValue>>, to path: KeyPath<To, FieldProperty<To, IDValue>>, method: SQLJoinMethod = .inner) -> Self {
        self.join(To.schemaOrAlias, method: method, on: "\"\(From.schemaOrAlias)\".\"\(From()[keyPath: from].key.description)\"=\"\(To.schemaOrAlias)\".\"\(To()[keyPath: path].key.description)\"")
    }

    public func all<A, B>(decoding: A.Type, _ bType: B.Type) -> EventLoopFuture<[(A, B)]>
        where A: Decodable, B: Decodable {
        self.all().flatMapThrowing {
            try $0.map {
                try (
                    $0.decode(model: A.self),
                    $0.decode(model: B.self)
                )
            }
        }
    }
}
