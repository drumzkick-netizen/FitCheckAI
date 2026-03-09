//
//  PhotoPurposeTips.swift
//  FitCheckAI
//

import Foundation

/// Purpose-specific photo guidance for better analysis results.
struct PurposeTipSet {
    let title: String
    let description: String
    let tips: [String]
}

enum PhotoPurposeTips {
    /// Full guidance (title, description, 2–4 tips) for a purpose.
    static func tips(for purpose: PhotoPurpose) -> PurposeTipSet {
        switch purpose {
        case .outfit:
            return PurposeTipSet(
                title: "Outfit Check",
                description: "Show your outfit clearly for accurate style feedback.",
                tips: [
                    "Show full body or upper body so clothing is visible",
                    "Make sure clothing is clearly visible and in focus",
                    "Try a slightly different angle for variety"
                ]
            )
        case .dating:
            return PurposeTipSet(
                title: "Dating Profile",
                description: "A clear, approachable photo works best.",
                tips: [
                    "Show your face clearly with a warm, natural expression",
                    "Use good lighting—natural light is ideal",
                    "Avoid overly distant or blurry shots"
                ]
            )
        case .social:
            return PurposeTipSet(
                title: "Social Media",
                description: "Make sure you're the focus of the shot.",
                tips: [
                    "Use a clear, high-quality photo",
                    "Make sure you are the main focus",
                    "Experiment with lighting direction"
                ]
            )
        case .professional:
            return PurposeTipSet(
                title: "Professional",
                description: "Clean and confident presentation.",
                tips: [
                    "Show your face clearly with confident posture",
                    "Use a clean, uncluttered background",
                    "Prefer balanced framing and even lighting"
                ]
            )
        case .compare:
            return PurposeTipSet(
                title: "Photo Battle",
                description: "Choose two similar photos for a fair comparison.",
                tips: [
                    "Pick two photos that clearly show you",
                    "Use similar framing and quality for both",
                    "Same lighting or pose helps compare fairly"
                ]
            )
        case .improveFit:
            return PurposeTipSet(title: "Improve Fit", description: "Get suggestions to improve your outfit.", tips: [])
        }
    }

    /// One-line hint for purpose selection cards (e.g. "Best with full-body or upper-body photos").
    static func oneLineHint(for purpose: PhotoPurpose) -> String {
        switch purpose {
        case .outfit: return "Best with full-body or upper-body photos"
        case .dating: return "Best with clear face and upper-body photos"
        case .social: return "Best with you as the clear focus"
        case .professional: return "Best with clear face and clean background"
        case .compare: return "Best with two similar photos of you"
        case .improveFit: return "Get improvement suggestions"
        }
    }

    /// Short tip for CaptureView when a purpose is already selected (e.g. Quick Mode).
    static func captureHint(for purpose: PhotoPurpose?) -> String? {
        guard let purpose else { return nil }
        switch purpose {
        case .outfit: return "Tip: use a full-body or upper-body photo"
        case .dating: return "Tip: use a clear face or upper-body photo"
        case .social: return "Tip: use a photo where you're the main focus"
        case .professional: return "Tip: use a clear face shot with a clean background"
        case .compare: return "Tip: pick a photo that clearly shows you"
        case .improveFit: return "Tip: get actionable improvement suggestions"
        }
    }
}
