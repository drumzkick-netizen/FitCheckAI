//
//  AppColors.swift
//  FitCheckAI
//

import SwiftUI

enum AppColors {
    static let background = Color(red: 0.08, green: 0.08, blue: 0.12)
    static let cardBackground = Color(red: 0.14, green: 0.14, blue: 0.18)
    static let cardBackgroundElevated = Color(red: 0.18, green: 0.18, blue: 0.22)
    static let mutedText = Color(red: 0.55, green: 0.55, blue: 0.6)
    static let accent = Color(red: 0.6, green: 0.4, blue: 1.0)
    static let accentSecondary = Color(red: 0.9, green: 0.45, blue: 0.85)
    static let scoreHigh = Color(red: 0.2, green: 0.8, blue: 0.5)
    static let scoreMid = Color(red: 0.2, green: 0.7, blue: 0.75)
    static let scoreLow = Color(red: 0.95, green: 0.75, blue: 0.2)
    static let scorePoor = Color(red: 0.95, green: 0.35, blue: 0.35)

    /// Shared score color for compact displays (e.g. Recent Results). Bands: 9+ green, 7.5–9 teal, 6–7.5 yellow, below 6 red.
    static func scoreColor(for score: Double) -> Color {
        switch score {
        case 9...10: return scoreHigh
        case 7.5..<9: return scoreMid
        case 6..<7.5: return scoreLow
        default: return scorePoor
        }
    }
}
