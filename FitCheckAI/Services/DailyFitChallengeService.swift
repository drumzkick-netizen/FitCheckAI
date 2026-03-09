//
//  DailyFitChallengeService.swift
//  FitCheckAI
//

import Foundation

/// Lightweight daily challenge: one prompt per day (local date). Used for retention and re-engagement.
enum DailyFitChallengeService {
    private static let challengePrompts: [String] = [
        "Best Casual Fit",
        "Best Date Night Fit",
        "Best Layered Look",
        "Best Minimalist Fit",
        "Best Streetwear Fit",
        "Best Work Fit",
    ]

    /// Index into challengePrompts based on calendar day of year. Same challenge all day.
    static var todayChallengePrompt: String {
        let dayOfYear = Calendar.current.component(.dayOfYear, from: Date())
        let index = dayOfYear % challengePrompts.count
        return challengePrompts[index]
    }
}
