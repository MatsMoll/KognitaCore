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
}
