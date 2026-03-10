//
//  AnalysisAPIModels.swift
//  FitCheckAI
//

import Foundation

struct AnalyzePhotoRequestDTO: Encodable {
    let imageBase64: String
    let purpose: String
}

/// Tolerant decoding: missing or invalid fields default to 0 so decode never crashes.
struct AnalyzePhotoResponseSubscoresDTO: Decodable {
    let composition: Double
    let lighting: Double
    let presentation: Double
    let purposeFit: Double

    enum CodingKeys: String, CodingKey {
        case composition, lighting, presentation, purposeFit
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        composition = (try? c.decode(Double.self, forKey: .composition)) ?? 0
        lighting = (try? c.decode(Double.self, forKey: .lighting)) ?? 0
        presentation = (try? c.decode(Double.self, forKey: .presentation)) ?? 0
        purposeFit = (try? c.decode(Double.self, forKey: .purposeFit)) ?? 0
    }
}

/// Tolerant decoding: missing or invalid fields yield nil so decode never crashes.
struct AnalyzePhotoDebugDTO: Decodable {
    let visibleFactsSummary: [String: String?]?
    let evaluability: String?
    let visibleFactsFromFallback: Bool?
    let strengthsCount: Int?
    let improvementsCount: Int?
    let suggestionsCount: Int?

    enum CodingKeys: String, CodingKey {
        case visibleFactsSummary, evaluability, visibleFactsFromFallback
        case strengthsCount, improvementsCount, suggestionsCount
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        visibleFactsSummary = try? c.decode([String: String?].self, forKey: .visibleFactsSummary)
        evaluability = try? c.decode(String.self, forKey: .evaluability)
        visibleFactsFromFallback = try? c.decode(Bool.self, forKey: .visibleFactsFromFallback)
        strengthsCount = try? c.decode(Int.self, forKey: .strengthsCount)
        improvementsCount = try? c.decode(Int.self, forKey: .improvementsCount)
        suggestionsCount = try? c.decode(Int.self, forKey: .suggestionsCount)
    }
}

/// Tolerant decoding: missing or null arrays default to []; missing isValid defaults to true so decode never crashes.
struct AnalyzePhotoResponseDTO: Decodable {
    let isValid: Bool
    let validationMessage: String?
    let reason: String?
    let score: Double?
    let subscores: AnalyzePhotoResponseSubscoresDTO?
    let strengths: [String]
    let improvements: [String]
    let suggestions: [String]
    let scoreExplanation: String?
    let analysisTips: [String]?
    let improvementSuggestions: [String]?
    let debug: AnalyzePhotoDebugDTO?

    enum CodingKeys: String, CodingKey {
        case isValid, validationMessage, reason, score, subscores
        case strengths, improvements, suggestions, scoreExplanation
        case analysisTips, improvementSuggestions, debug
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        isValid = (try? c.decode(Bool.self, forKey: .isValid)) ?? true
        validationMessage = try? c.decode(String.self, forKey: .validationMessage)
        reason = try? c.decode(String.self, forKey: .reason)
        score = try? c.decode(Double.self, forKey: .score)
        subscores = try? c.decode(AnalyzePhotoResponseSubscoresDTO.self, forKey: .subscores)
        strengths = (try? c.decode([String].self, forKey: .strengths)) ?? []
        improvements = (try? c.decode([String].self, forKey: .improvements)) ?? []
        suggestions = (try? c.decode([String].self, forKey: .suggestions)) ?? []
        scoreExplanation = try? c.decode(String.self, forKey: .scoreExplanation)
        analysisTips = try? c.decode([String].self, forKey: .analysisTips)
        improvementSuggestions = try? c.decode([String].self, forKey: .improvementSuggestions)
        debug = try? c.decode(AnalyzePhotoDebugDTO.self, forKey: .debug)
    }
}
