//
//  QueryBuilder+extension.swift
//  KognitaCore
//
//  Created by Mats Mollestad on 14/11/2020.
//
// swiftlint:disable large_tuple

import Vapor
import FluentSQL
import Fluent

extension QueryBuilder {
    public func all<Joined>(
        _ joined: Joined.Type
    ) -> EventLoopFuture<[Joined]>
        where
            Joined: Schema {
        let copy = self.copy()
        return copy.all().flatMapThrowing {
            try $0.map { try $0.joined(Joined.self) }
        }
    }

    public func all<Joined, JoinedTwo>(
        _ joined: Joined.Type,
        _ joinedTwo: JoinedTwo.Type
    ) -> EventLoopFuture<[(Joined, JoinedTwo)]>
        where Joined: Schema, JoinedTwo: Schema {
        let copy = self.copy()
        return copy.all().flatMapThrowing {
            try $0.map { try ($0.joined(Joined.self), $0.joined(JoinedTwo.self)) }
        }
    }

    public func all<Joined, JoinedTwo, JoinedThree>(
        _ joined: Joined.Type,
        _ joinedTwo: JoinedTwo.Type,
        _ joinedThree: JoinedThree.Type
    ) -> EventLoopFuture<[(Joined, JoinedTwo, JoinedThree)]>
        where Joined: Schema, JoinedTwo: Schema, JoinedThree: Schema {
        let copy = self.copy()
        return copy.all().flatMapThrowing {
            try $0.map { try ($0.joined(Joined.self), $0.joined(JoinedTwo.self), $0.joined(JoinedThree.self)) }
        }
    }

    public func all<Joined, JoinedTwo, JoinedThree>(
        _ joined: Joined.Type,
        _ joinedTwo: JoinedTwo.Type,
        _ joinedThree: Optional<JoinedThree>.Type
    ) -> EventLoopFuture<[(Joined, JoinedTwo, JoinedThree?)]>
        where Joined: Schema, JoinedTwo: Schema, JoinedThree: Schema {
        let copy = self.copy()
        return copy.all().flatMapThrowing {
            try $0.map { try ($0.joined(Joined.self), $0.joined(JoinedTwo.self), try? $0.joined(JoinedThree.self)) }
        }
    }

    public func all<Joined, JoinedTwo, JoinedThree, Four>(
        _ joined: Joined.Type,
        _ joinedTwo: JoinedTwo.Type,
        _ joinedThree: JoinedThree.Type,
        _ four: Optional<Four>.Type
    ) -> EventLoopFuture<[(Joined, JoinedTwo, JoinedThree, Four?)]>
        where Joined: Schema, JoinedTwo: Schema, JoinedThree: Schema, Four: Schema {
        let copy = self.copy()
        return copy.all().flatMapThrowing {
            try $0.map { try ($0.joined(Joined.self), $0.joined(JoinedTwo.self), $0.joined(JoinedThree.self), try? $0.joined(Four.self)) }
        }
    }

    public func all<Joined, JoinedTwo>(
        _ joined: Joined.Type,
        _ joinedTwo: Optional<JoinedTwo>.Type
    ) -> EventLoopFuture<[(Joined, JoinedTwo?)]>
        where Joined: Schema, JoinedTwo: Schema {
        let copy = self.copy()
        return copy.all().flatMapThrowing {
            try $0.map { (try $0.joined(Joined.self), try? $0.joined(JoinedTwo.self)) }
        }
    }
    
    public func all<Joined, JoinedTwo, JoinedThird>(
        _ joined: Joined.Type,
        _ joinedTwo: Optional<JoinedTwo>.Type,
        _ joinedThired: Optional<JoinedThird>.Type
    ) -> EventLoopFuture<[(Joined, JoinedTwo?, JoinedThird?)]>
    where Joined: Schema, JoinedTwo: Schema, JoinedThird: Schema {
        let copy = self.copy()
        return copy.all().flatMapThrowing {
            try $0.map { (try $0.joined(Joined.self), try? $0.joined(JoinedTwo.self), try? $0.joined(JoinedThird.self)) }
        }
    }

    public func first<Joined>(
        _ joined: Joined.Type
    ) -> EventLoopFuture<Joined?>
        where
            Joined: Schema {
        let copy = self.copy()
        return copy.first().flatMapThrowing {
            try $0?.joined(Joined.self)
        }
    }

    public func first<Joined, JoinedTwo>(
        _ joined: Joined.Type, _ joinedTwo: JoinedTwo.Type
    ) -> EventLoopFuture<(Joined, JoinedTwo)?>
        where
        Joined: Schema,
        JoinedTwo: Schema {
        let copy = self.copy()
        return copy.first().flatMapThrowing {
            guard let joined = try $0?.joined(Joined.self), let joinedTwo = try $0?.joined(JoinedTwo.self) else { return nil }
            return (joined, joinedTwo)
        }
    }

    public func first<Joined, JoinedTwo, JoinedThree>(
        _ joined: Joined.Type, _ joinedTwo: JoinedTwo.Type, _ joinedThree: JoinedThree.Type
    ) -> EventLoopFuture<(Joined, JoinedTwo, JoinedThree)?>
        where
        Joined: Schema,
        JoinedTwo: Schema,
        JoinedThree: Schema {
        let copy = self.copy()
        return copy.first().flatMapThrowing {
            guard let joined = try $0?.joined(Joined.self), let joinedTwo = try $0?.joined(JoinedTwo.self), let joinedThree = try $0?.joined(JoinedThree.self) else { return nil }
            return (joined, joinedTwo, joinedThree)
        }
    }

    public func first<Joined, JoinedTwo>(
        _ joined: Joined.Type, _ joinedTwo: Optional<JoinedTwo>.Type
    ) -> EventLoopFuture<(Joined, JoinedTwo?)?>
        where
        Joined: Schema,
        JoinedTwo: Schema {
        let copy = self.copy()
        return copy.first().flatMapThrowing {
            guard let joined = try $0?.joined(Joined.self) else { return nil }
            return (joined, try? $0?.joined(JoinedTwo.self))
        }
    }

    public func first<Joined, JoinedTwo, JoinedThird>(
        _ joined: Joined.Type, _ joinedTwo: Optional<JoinedTwo>.Type, _ joinedThird: Optional<JoinedThird>.Type
    ) -> EventLoopFuture<(Joined, JoinedTwo?, JoinedThird?)?>
        where
        Joined: Schema,
        JoinedTwo: Schema,
        JoinedThird: Schema {
        let copy = self.copy()
        return copy.first().flatMapThrowing {
            guard let joined = try $0?.joined(Joined.self) else { return nil }
            return (joined, try? $0?.joined(JoinedTwo.self), try? $0?.joined(JoinedThird.self))
        }
    }
}
