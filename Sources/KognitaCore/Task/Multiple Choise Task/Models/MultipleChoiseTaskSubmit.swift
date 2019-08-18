//
//  MultipleChoiseTaskSubmit.swift
//  App
//
//  Created by Mats Mollestad on 27/01/2019.
//

import Vapor

/// The content needed to submit a answer to a `MultipleChoiseTask`
public final class MultipleChoiseTaskSubmit: Content, TaskSubmitable {

    /// The time used to answer the question
    public let timeUsed: TimeInterval

    /// The choise id's
    public let choises: [MultipleChoiseTaskChoise.ID]
}

public final class MultipleChoiseTaskChoiseResult: Content {
    public let id: MultipleChoiseTaskChoise.ID
    public let isCorrect: Bool

    init(id: MultipleChoiseTaskChoise.ID, isCorrect: Bool) {
        self.id = id
        self.isCorrect = isCorrect
    }
}
