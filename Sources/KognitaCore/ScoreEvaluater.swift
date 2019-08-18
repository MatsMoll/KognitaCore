//
//  ScoreEvaluater.swift
//  App
//
//  Created by Mats Mollestad on 08/05/2019.
//

class ScoreEvaluater {
    static let shared = ScoreEvaluater()

    func compress(score: Double, range: ClosedRange<Double>) -> Double {
        return ((score - range.lowerBound) / (range.upperBound - range.lowerBound)).clamped(to: 0...1)
    }

    func daysUntillReview(score: Double) -> Int {
        switch score {
        case 0.2..<0.4: return 3
        case 0.4..<0.6: return 7
        case 0.6..<0.8: return 16
        case 0.8...1: return 30
        default: return 1
        }
    }
}
