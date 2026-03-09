//
//  BeatYourScoreResult.swift
//  FitCheckAI
//

import Foundation

/// A completed Beat Your Score comparison saved to history.
struct BeatYourScoreResult: Identifiable, Codable, Hashable {
    let id: UUID
    let date: Date
    let originalImageData: Data
    let newImageData: Data
    let originalScore: Double
    let newScore: Double
    /// True if new score > original.
    let improved: Bool

    init(
        id: UUID = UUID(),
        date: Date = Date(),
        originalImageData: Data,
        newImageData: Data,
        originalScore: Double,
        newScore: Double
    ) {
        self.id = id
        self.date = date
        self.originalImageData = originalImageData
        self.newImageData = newImageData
        self.originalScore = originalScore
        self.newScore = newScore
        self.improved = newScore > originalScore
    }

    var scoreDifference: Double { newScore - originalScore }
}
