//
//  MultipleChoiseTaskContent.swift
//  KognitaCore
//
//  Created by Mats Mollestad on 10/04/2019.
//

import Vapor

public final class MultipleChoiseTaskContent: Content {

    public let task: Task

    public let choises: [MultipleChoiseTaskChoise]

    public let isMultipleSelect: Bool

    init(task: Task, multipleTask: MultipleChoiseTask, choises: [MultipleChoiseTaskChoise]) {
        self.task               = task
        self.isMultipleSelect   = multipleTask.isMultipleSelect
        self.choises            = choises
    }
}
