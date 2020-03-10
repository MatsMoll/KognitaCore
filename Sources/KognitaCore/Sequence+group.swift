//
//  Sequence+group.swift
//  KognitaCore
//
//  Created by Mats Mollestad on 01/05/2019.
//

import Foundation

extension Sequence {

    public func group<P>(by path: KeyPath<Element, P>) -> [P : [Element]] where P : Hashable {
        return Dictionary(grouping: self) { $0[keyPath: path] }
    }

    public func count<T>(equal path: KeyPath<Element, T>) -> [T : Int] where T : Hashable {
        var counts = [T : Int]()
        for object in self {
            let value = object[keyPath: path]
            if let count = counts[value] {
                counts[value] = count + 1
            } else {
                counts[value] = 1
            }
        }
        return counts
    }
}
