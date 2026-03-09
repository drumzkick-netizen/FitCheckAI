//
//  PhotoBattleResult.swift
//  FitCheckAI
//

import Foundation

/// A completed Photo Battle comparison saved to history.
struct PhotoBattleResult: Identifiable, Codable, Hashable {
    let id: UUID
    let date: Date
    let imageAData: Data
    let imageBData: Data
    let scoreA: Double
    let scoreB: Double
    let winner: CompareWinner

    init(
        id: UUID = UUID(),
        date: Date = Date(),
        imageAData: Data,
        imageBData: Data,
        scoreA: Double,
        scoreB: Double,
        winner: CompareWinner
    ) {
        self.id = id
        self.date = date
        self.imageAData = imageAData
        self.imageBData = imageBData
        self.scoreA = scoreA
        self.scoreB = scoreB
        self.winner = winner
    }
}
