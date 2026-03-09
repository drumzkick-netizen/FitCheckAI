//
//  ShareScoreCardView.swift
//  FitCheckAI
//

import SwiftUI

/// Strongest subscore for optional share card line, e.g. "Lighting 8.4". Returns nil if no subscores.
enum ShareScoreCardSubscores {
    static func strongestLine(from subscores: AnalysisSubscores?) -> String? {
        guard let s = subscores else { return nil }
        let pairs: [(String, Double)] = [
            ("Composition", s.composition),
            ("Lighting", s.lighting),
            ("Presentation", s.presentation),
            ("Purpose Fit", s.purposeFit),
        ]
        guard let best = pairs.max(by: { $0.1 < $1.1 }) else { return nil }
        return "\(best.0) \(ScoreFormat.display(best.1))"
    }
}

/// One-sentence summary for the share card: first strength, else first suggestion. Kept short and natural.
enum ShareScoreCardSummary {
    static func line(from result: AnalysisResult) -> String {
        let raw: String
        if let first = result.strengths.first, !first.isEmpty {
            raw = first
        } else if let first = result.suggestions.first, !first.isEmpty {
            raw = first
        } else {
            return "Strong composition and good presentation."
        }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if let period = trimmed.firstIndex(of: ".") {
            return String(trimmed[..<period]).trimmingCharacters(in: .whitespaces) + "."
        }
        let maxLen = 80
        if trimmed.count <= maxLen { return trimmed }
        let prefix = String(trimmed.prefix(maxLen))
        if let lastSpace = prefix.lastIndex(of: " ") {
            return String(prefix[..<lastSpace]).trimmingCharacters(in: .whitespaces) + "."
        }
        return prefix.trimmingCharacters(in: .whitespaces) + "..."
    }
}

/// Premium shareable score card for single-photo analysis: branding, photo, score, verdict, tier. Renders to image for share sheet.
struct ShareScoreCardView: View {
    let image: UIImage
    let purpose: PhotoPurpose
    let result: AnalysisResult

    private static let cardWidth: CGFloat = 400
    private static let imageHeight: CGFloat = 220
    private static let contentHeight: CGFloat = 258

    private var scoreColor: Color {
        AppColors.scoreColor(for: result.score)
    }

    private var insight: ScoreInsight {
        ScoreInsights.insight(for: result.score)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Top: branding
            Text("FitCheckAI")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(AppColors.mutedText.opacity(0.9))
                .padding(.top, 14)
                .padding(.bottom, 8)

            // Photo
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: Self.cardWidth, height: Self.imageHeight)
                .clipped()

            // Content: score + verdict + optional tier
            VStack(spacing: 12) {
                ScoreRingView(score: result.score, size: 88, lineWidth: 10, animateOnAppear: false)
                    .padding(.top, 20)

                Text(ScoreInsights.verdictLine(for: result))
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(AppColors.mutedText)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .padding(.horizontal, 24)

                if !insight.rankLabel.isEmpty {
                    Text(insight.rankLabel)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(scoreColor)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 5)
                        .background(scoreColor.opacity(0.2))
                        .clipShape(Capsule())
                }

                Text(insight.percentileText)
                    .font(.caption)
                    .foregroundStyle(AppColors.mutedText.opacity(0.85))

                if let strongest = ShareScoreCardSubscores.strongestLine(from: result.subscores) {
                    Text(strongest)
                        .font(.caption2)
                        .foregroundStyle(AppColors.mutedText.opacity(0.75))
                }

                Spacer(minLength: 8)

                Text("FitCheckAI")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(AppColors.mutedText.opacity(0.6))
                    .padding(.bottom, 20)
            }
            .frame(width: Self.cardWidth, height: Self.contentHeight)
            .background(AppColors.cardBackground)
        }
        .frame(width: Self.cardWidth, height: 14 + 8 + Self.imageHeight + Self.contentHeight)
        .background(AppColors.background)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(
                    LinearGradient(
                        colors: [
                            AppColors.accent.opacity(0.35),
                            AppColors.accentSecondary.opacity(0.15)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
    }
}

#Preview {
    let result = AnalysisResult(
        score: 8.2,
        subscores: AnalysisSubscores(composition: 8.0, lighting: 8.4, presentation: 8.1, purposeFit: 8.3),
        strengths: ["Strong composition and good presentation."],
        improvements: ["Slightly tighter crop could help."],
        suggestions: ["Try natural light for warmth."]
    )
    let placeholder = UIImage(systemName: "photo.fill") ?? UIImage()
    ShareScoreCardView(
        image: placeholder,
        purpose: .outfit,
        result: result
    )
    .preferredColorScheme(.dark)
}
