//
//  ScoreInsights.swift
//  FitCheckAI
//

import Foundation

/// Deterministic percentile/ranking from score. Purely local, no backend. Score-only mapping.
struct ScoreInsight {
    /// e.g. "Top 18% today" or "Above average"
    let percentileText: String
    /// e.g. "Better than 82% today" (empty for non-percent tiers like Average / Needs Work)
    let betterThanText: String
    /// Elite / Strong / Solid / Average / Needs Work
    let rankLabel: String
    /// Backward compatibility: same as percentileText for display.
    var topPercentText: String { percentileText }
    /// Short form for hero pill, e.g. "Top 18%", "Above avg"
    var shortPercentileText: String {
        if percentileText.hasPrefix("Top "), percentileText.contains("%") {
            return percentileText.replacingOccurrences(of: " today", with: "")
        }
        if percentileText == "Above average" { return "Above avg" }
        if percentileText == "Needs work" { return "Needs work" }
        return percentileText
    }
}

enum ScoreInsights {
    /// Deterministic insight from score (0–10). No networking, no randomness.
    static func insight(for score: Double) -> ScoreInsight {
        let clamped = min(10, max(0, score))
        switch clamped {
        case 9.5...10:
            return ScoreInsight(
                percentileText: "Top 5% today",
                betterThanText: "Better than 95% today",
                rankLabel: "Elite"
            )
        case 9.0..<9.5:
            return ScoreInsight(
                percentileText: "Top 10% today",
                betterThanText: "Better than 90% today",
                rankLabel: "Elite"
            )
        case 8.5..<9.0:
            return ScoreInsight(
                percentileText: "Top 18% today",
                betterThanText: "Better than 82% today",
                rankLabel: "Strong"
            )
        case 8.0..<8.5:
            return ScoreInsight(
                percentileText: "Top 25% today",
                betterThanText: "Better than 75% today",
                rankLabel: "Strong"
            )
        case 7.5..<8.0:
            return ScoreInsight(
                percentileText: "Top 35% today",
                betterThanText: "Better than 65% today",
                rankLabel: "Solid"
            )
        case 7.0..<7.5:
            return ScoreInsight(
                percentileText: "Top 45% today",
                betterThanText: "Better than 55% today",
                rankLabel: "Solid"
            )
        case 6.5..<7.0:
            return ScoreInsight(
                percentileText: "Above average",
                betterThanText: "Better than 50% today",
                rankLabel: "Solid"
            )
        case 6.0..<6.5:
            return ScoreInsight(
                percentileText: "Average",
                betterThanText: "Better than 40% today",
                rankLabel: "Average"
            )
        default:
            return ScoreInsight(
                percentileText: "Needs work",
                betterThanText: "",
                rankLabel: "Needs Work"
            )
        }
    }

    /// One short supporting line for the hero section; distinct from rank label (e.g. not "Solid result" when rank is "Solid").
    static func supportingLine(for score: Double) -> String {
        let clamped = min(10, max(0, score))
        switch clamped {
        case 9...10: return "Strong overall presentation"
        case 8..<9: return "Strong overall presentation"
        case 7..<8: return "A solid starting point"
        case 6..<7: return "Good baseline score"
        case 5..<6: return "Room to improve"
        default: return "Keep refining"
        }
    }

    /// Short verdict line for the Results hero (e.g. "Clean, confident casual fit"). Prefers first strength when concise; else score-based.
    static func verdictLine(for result: AnalysisResult) -> String {
        if let first = result.strengths.first, !first.isEmpty {
            let t = first.trimmingCharacters(in: .whitespacesAndNewlines)
            let trimmed = t.hasSuffix(".") ? String(t.dropLast()) : t
            if trimmed.count <= 55, !trimmed.isEmpty { return trimmed }
        }
        return verdictLineFallback(for: result.score)
    }

    private static func verdictLineFallback(for score: Double) -> String {
        switch min(10, max(0, score)) {
        case 9...10: return "Exceptional fit and presentation"
        case 8..<9: return "Strong presentation with stylish coordination"
        case 7..<8: return "Clean, confident casual fit"
        case 6..<7: return "Well-put-together look with room to improve"
        case 5..<6: return "Solid base with clear next steps"
        default: return "Room to refine and level up"
        }
    }

    /// One-sentence score explanation for the hero section. Uses backend value when present; otherwise human-sounding line from subscores.
    static func scoreExplanationLine(for result: AnalysisResult) -> String? {
        let trimmed = result.scoreExplanation?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let s = trimmed, !s.isEmpty { return s }

        guard let sub = result.subscores else { return nil }
        let entries: [(String, Double)] = [
            ("composition", sub.composition),
            ("lighting", sub.lighting),
            ("presentation", sub.presentation),
            ("purpose fit", sub.purposeFit),
        ]
        let sorted = entries.sorted { $0.1 > $1.1 }
        let strong = sorted[0]
        let weak = sorted[3]
        if abs(strong.1 - weak.1) < 0.3 { return nil }
        let strongName = humanDimensionName(strong.0)
        let weakName = humanDimensionName(weak.0)
        let secondName = humanDimensionName(sorted[1].0)
        return "\(strongName) and \(secondName) carry this look, while \(weakName) softens the score slightly."
    }

    private static func humanDimensionName(_ key: String) -> String {
        switch key {
        case "composition": return "Composition"
        case "lighting": return "Lighting"
        case "presentation": return "Presentation"
        case "purpose fit": return "Purpose fit"
        default: return key.prefix(1).uppercased() + key.dropFirst()
        }
    }
}
