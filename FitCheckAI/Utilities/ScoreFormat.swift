//
//  ScoreFormat.swift
//  FitCheckAI
//

import Foundation

/// Single place for score and subscore display formatting. All scores shown in the app use one decimal place.
enum ScoreFormat {
    /// Rounds to one decimal (0.0–10.0) and returns a string for display (e.g. "8.2", "7.3").
    /// Use for overall score and all breakdown scores.
    static func display(_ score: Double) -> String {
        let rounded = (score * 10).rounded() / 10
        let clamped = min(10, max(0, rounded))
        return String(format: "%.1f", clamped)
    }

    /// Percentile stays whole number; this enum is for score formatting only.
    /// Percentile display is unchanged (e.g. "Top 18% today").
}
