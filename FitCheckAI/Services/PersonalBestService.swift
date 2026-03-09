//
//  PersonalBestService.swift
//  FitCheckAI
//

import Foundation

/// Tracks the user's best single-photo score locally (UserDefaults).
/// Used for "Best Score" on Home and "New Personal Best" on result screen.
final class PersonalBestService {
    static let shared = PersonalBestService()

    private let scoreKey = "fitcheck_personal_best_score"
    private let dateKey = "fitcheck_personal_best_date"

    private var defaults: UserDefaults { UserDefaults.standard }

    var bestScore: Double? {
        let v = defaults.double(forKey: scoreKey)
        return v > 0 ? v : nil
    }

    var bestScoreDate: Date? {
        defaults.object(forKey: dateKey) as? Date
    }

    private init() {}

    /// Updates personal best if the given score is higher. Returns true if this score is a new record.
    @discardableResult
    func updateIfBetter(score: Double) -> Bool {
        let current = bestScore ?? 0
        guard score > current else { return false }
        defaults.set(score, forKey: scoreKey)
        defaults.set(Date(), forKey: dateKey)
        return true
    }

    /// Clears stored personal best (e.g. for testing).
    func clear() {
        defaults.removeObject(forKey: scoreKey)
        defaults.removeObject(forKey: dateKey)
    }
}
