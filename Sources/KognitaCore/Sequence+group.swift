//
//  Sequence+group.swift
//  KognitaCore
//
//  Created by Mats Mollestad on 01/05/2019.
//

import Foundation

extension Sequence {

    public func group<P>(by path: KeyPath<Element, P>) -> [P : [Element]] where P : Hashable {
        var result = [P : [Element]]()
        for object in self {
            let value = object[keyPath: path]
            if let group = result[value] {
                result[value] = group + [object]
            } else {
                result[value] = [object]
            }
        }
        return result
    }
}
