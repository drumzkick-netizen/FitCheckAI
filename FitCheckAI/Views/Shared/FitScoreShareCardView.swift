//
//  FitScoreShareCardView.swift
//  FitCheckAI
//

import SwiftUI

/// Tier label for the share card. Used only for FitScoreShareCardView.
enum FitScoreShareTier {
    static func label(for score: Double) -> String {
        switch score {
        case 9.5...10: return "Legendary Fit"
        case 9.0..<9.5: return "Elite Fit"
        case 8.0..<9.0: return "Strong Fit"
        case 7.0..<8.0: return "Solid Fit"
        case 6.0..<7.0: return "Mid Fit"
        default: return "Needs Work"
        }
    }
}

/// Shareable Fit Score Card for Instagram/TikTok/Snap/Stories. Designed at 1080×1920 (vertical). Punchy, post-worthy.
struct FitScoreShareCardView: View {
    let image: UIImage
    let result: AnalysisResult

    /// Design size for rendering; render at 1080×1920.
    static let designWidth: CGFloat = 1080
    static let designHeight: CGFloat = 1920

    private var scoreColor: Color {
        AppColors.scoreColor(for: result.score)
    }

    private var tierLabel: String {
        FitScoreShareTier.label(for: result.score)
    }

    /// Top 2 strengths only — keeps card punchy and social-friendly.
    private var displayStrengths: [String] {
        Array(result.strengths.prefix(2)).filter { !$0.isEmpty }
    }

    private var shareGradient: LinearGradient {
        LinearGradient(
            colors: [
                AppColors.background,
                AppColors.background,
                AppColors.accent.opacity(0.06)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    var body: some View {
        ZStack {
            shareGradient
                .ignoresSafeArea()

            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            AppColors.accent.opacity(0.12),
                            AppColors.accent.opacity(0.03),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: 380
                    )
                )
                .frame(width: 760, height: 760)
                .blur(radius: 100)
                .offset(y: -300)

            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            AppColors.accentSecondary.opacity(0.06),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: 260
                    )
                )
                .frame(width: 520, height: 520)
                .blur(radius: 70)
                .offset(x: 100, y: 380)

            VStack(spacing: 0) {
                // Brand
                Text("FitCheck AI")
                    .font(.system(size: 44, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.top, 72)
                    .padding(.bottom, 32)

                // Score + tier (strong hierarchy)
                VStack(spacing: 12) {
                    Text(ScoreFormat.display(result.score))
                        .font(.system(size: 172, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .shadow(color: scoreColor.opacity(0.35), radius: 16)

                    Text(tierLabel)
                        .font(.system(size: 40, weight: .bold))
                        .foregroundStyle(scoreColor)
                }
                .padding(.bottom, 28)

                // Photo — clean frame, centered
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 360, height: 360)
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color.white.opacity(0.12), lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.25), radius: 16, y: 8)
                    .padding(.horizontal, 60)

                // Top 2 strengths + watermark
                VStack(spacing: 18) {
                    if !displayStrengths.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            ForEach(Array(displayStrengths.enumerated()), id: \.offset) { _, strength in
                                HStack(alignment: .top, spacing: 10) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 26))
                                        .foregroundStyle(scoreColor)
                                    Text(strength)
                                        .font(.system(size: 26, weight: .medium))
                                        .foregroundStyle(.white.opacity(0.95))
                                        .lineLimit(2)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    Text("Rated by FitCheck AI")
                        .font(.system(size: 22, weight: .medium))
                        .foregroundStyle(AppColors.mutedText.opacity(0.75))
                }
                .padding(.horizontal, 48)
                .padding(.vertical, 28)
                .background(
                    RoundedRectangle(cornerRadius: 24)
                        .fill(AppColors.cardBackground.opacity(0.9))
                        .overlay(
                            RoundedRectangle(cornerRadius: 24)
                                .stroke(Color.white.opacity(0.08), lineWidth: 1)
                        )
                )
                .padding(.horizontal, 40)
                .padding(.top, 28)
                .padding(.bottom, 64)
            }
        }
        .frame(width: Self.designWidth, height: Self.designHeight)
        .clipShape(RoundedRectangle(cornerRadius: 0))
    }
}

#Preview {
    FitScoreShareCardView(
        image: UIImage(systemName: "photo.fill") ?? UIImage(),
        result: AnalysisResult(
            score: 8.7,
            subscores: AnalysisSubscores(composition: 8.5, lighting: 8.8, presentation: 8.6, purposeFit: 8.7),
            strengths: [
                "Jacket fit is clean at the shoulders.",
                "Shirt and trouser color balance works well.",
                "Silhouette reads streamlined."
            ],
            improvements: [],
            suggestions: []
        )
    )
    .preferredColorScheme(.dark)
}
