//
//  PhotoAnalysisService.swift
//  FitCheckAI
//

import Foundation

/// Result of analysis: either a valid result or a validation failure (invalid image).
enum AnalysisOutcome {
    case valid(AnalysisResult)
    case invalid(message: String)
}

protocol PhotoAnalysisServicing {
    func analyzePhoto(
        imageData: Data,
        purpose: PhotoPurpose
    ) async throws -> AnalysisOutcome
}

/// Subscores around the given score (e.g. 8.2 → values in 7.8–8.6). For mock only.
private func mockSubscores(for score: Double) -> AnalysisSubscores {
    AnalysisSubscores(
        composition: min(10, max(1, score - 0.2)),
        lighting: min(10, max(1, score + 0.2)),
        presentation: min(10, max(1, score - 0.1)),
        purposeFit: min(10, max(1, score + 0.1))
    )
}

final class MockPhotoAnalysisService: PhotoAnalysisServicing {
    func analyzePhoto(
        imageData: Data,
        purpose: PhotoPurpose
    ) async throws -> AnalysisOutcome {
        try await Task.sleep(nanoseconds: 1_500_000_000)

        switch purpose {
        case .outfit:
            return .valid(AnalysisResult(
                score: 8.2,
                subscores: mockSubscores(for: 8.2),
                strengths: ["Cohesive color palette", "Good fit and proportion"],
                improvements: ["Shoes could match the formality better", "Consider adding one accent piece"],
                suggestions: ["Try a belt to define the waist", "Layer with a jacket for depth"]
            ))
        case .dating:
            return .valid(AnalysisResult(
                score: 7.8,
                subscores: mockSubscores(for: 7.8),
                strengths: ["Approachable and genuine", "Good eye contact with camera"],
                improvements: ["Lighting is a bit flat", "Background could be more intentional"],
                suggestions: ["Use warmer natural light", "Choose a background that says something about you"]
            ))
        case .social:
            return .valid(AnalysisResult(
                score: 8.5,
                subscores: mockSubscores(for: 8.5),
                strengths: ["Strong composition", "Vibrant and shareable"],
                improvements: ["Slight overexposure on the left", "Crop could be tighter"],
                suggestions: ["Add a caption that tells a story", "Consider the grid layout for Instagram"]
            ))
        case .professional:
            return .valid(AnalysisResult(
                score: 8.0,
                subscores: mockSubscores(for: 8.0),
                strengths: ["Clean and polished", "Appropriate formality"],
                improvements: ["Background has visible clutter", "Framing could be more neutral"],
                suggestions: ["Use a plain wall or blur the background", "Ensure shoulders are squared to camera"]
            ))
        case .compare:
            return .valid(AnalysisResult(
                score: 7.5,
                subscores: mockSubscores(for: 7.5),
                strengths: ["Consistent lighting across options", "Clear view of both choices"],
                improvements: ["One option is partially cut off", "Angle makes comparison harder"],
                suggestions: ["Show both options in the same frame", "Use identical pose for fair comparison"]
            ))
        case .improveFit:
            return .valid(AnalysisResult(
                score: 7.8,
                subscores: mockSubscores(for: 7.8),
                strengths: ["Solid base outfit", "Good color coordination"],
                improvements: ["Proportions could be balanced better", "Accessories would elevate the look"],
                suggestions: ["Try a belt to define the waist", "Add one statement piece", "Consider layering for depth"]
            ))
        }
    }
}
