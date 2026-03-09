//
//  AnalysisAPIModels.swift
//  FitCheckAI
//

import Foundation

struct AnalyzePhotoRequestDTO: Encodable {
    let imageBase64: String
    let purpose: String
}

struct AnalyzePhotoResponseSubscoresDTO: Decodable {
    let composition: Double
    let lighting: Double
    let presentation: Double
    let purposeFit: Double
}

struct AnalyzePhotoDebugDTO: Decodable {
    let visibleFactsSummary: [String: String?]?
    let evaluability: String?
    let visibleFactsFromFallback: Bool?
    let strengthsCount: Int?
    let improvementsCount: Int?
    let suggestionsCount: Int?
}

struct AnalyzePhotoResponseDTO: Decodable {
    let isValid: Bool
    let validationMessage: String?
    let reason: String?
    let score: Double?
    let subscores: AnalyzePhotoResponseSubscoresDTO?
    let strengths: [String]
    let improvements: [String]
    let suggestions: [String]
    /// Optional one-sentence score explanation (backend-derived from subscores). Omitted in older API; safe to ignore.
    let scoreExplanation: String?
    /// Image-specific tips for better analysis (e.g. lighting/framing only when relevant). Omitted in older API.
    let analysisTips: [String]?
    /// When purpose is improve_fit: list of improvement suggestions. Omitted otherwise.
    let improvementSuggestions: [String]?
    /// Optional internal debug info for QA; only present when backend debug mode is enabled.
    let debug: AnalyzePhotoDebugDTO?
}
