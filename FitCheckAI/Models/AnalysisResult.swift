//
//  AnalysisResult.swift
//  FitCheckAI
//

import Foundation

/// Subscores from analysis (1–10). Optional for compatibility with older API responses.
struct AnalysisSubscores: Equatable, Hashable, Codable {
    let composition: Double
    let lighting: Double
    let presentation: Double
    let purposeFit: Double
}

/// Internal-only debug info mirrored from the backend when debug mode is enabled.
struct AnalysisDebugInfo: Equatable, Hashable, Codable {
    let visibleFactsSummary: [String: String?]?
    let evaluability: String?
    let visibleFactsFromFallback: Bool
    let strengthsCount: Int?
    let improvementsCount: Int?
    let suggestionsCount: Int?
}

struct AnalysisResult: Equatable, Hashable, Identifiable, Codable {
    let id: UUID
    let score: Double
    let subscores: AnalysisSubscores?
    let strengths: [String]
    let improvements: [String]
    let suggestions: [String]
    /// Optional one-sentence score explanation. From backend when present; otherwise derived from subscores on the client.
    let scoreExplanation: String?
    /// Image-specific tips for better analysis. From backend when present; nil for older API.
    let analysisTips: [String]?
    /// When purpose is improve_fit: list of improvement suggestions. From backend when present.
    let improvementSuggestions: [String]?
    /// Internal-only debug information for QA; populated when backend debug mode is enabled.
    let debugInfo: AnalysisDebugInfo?

    init(
        id: UUID = UUID(),
        score: Double,
        subscores: AnalysisSubscores? = nil,
        strengths: [String],
        improvements: [String],
        suggestions: [String],
        scoreExplanation: String? = nil,
        analysisTips: [String]? = nil,
        improvementSuggestions: [String]? = nil,
        debugInfo: AnalysisDebugInfo? = nil
    ) {
        self.id = id
        self.score = score
        self.subscores = subscores
        self.strengths = strengths
        self.improvements = improvements
        self.suggestions = suggestions
        self.scoreExplanation = scoreExplanation
        self.analysisTips = analysisTips
        self.improvementSuggestions = improvementSuggestions
        self.debugInfo = debugInfo
    }
}
