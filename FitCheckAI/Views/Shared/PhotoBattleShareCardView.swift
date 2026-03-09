//
//  PhotoBattleShareCardView.swift
//  FitCheckAI
//

import SwiftUI
import UIKit

/// Shareable Photo Battle card for Instagram/TikTok/Snap/X. Designed at 1080×1920 (vertical story).
/// Use PhotoBattleShareCardView.renderPhotoBattleShareCard(...) to get a UIImage for sharing.
struct PhotoBattleShareCardView: View {
    let imageA: UIImage
    let imageB: UIImage
    let scoreA: Double
    let scoreB: Double
    let winner: CompareWinner

    /// Design size for rendering; render at 1080×1920.
    static let designWidth: CGFloat = 1080
    static let designHeight: CGFloat = 1920

    private var winnerLabel: String {
        switch winner {
        case .photoA: return "Photo A Wins"
        case .photoB: return "Photo B Wins"
        case .tie: return "Tie"
        }
    }

    private var advantageText: String? {
        guard winner != .tie else { return nil }
        let diff = abs(scoreA - scoreB)
        return "+\(ScoreFormat.display(diff)) Advantage"
    }

    private var shareGradient: LinearGradient {
        LinearGradient(
            colors: [
                AppColors.background,
                AppColors.background,
                AppColors.accent.opacity(0.08)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    var body: some View {
        ZStack {
            // Background
            shareGradient
                .ignoresSafeArea()

            // Soft purple orbs (same style as Home / Fit Score card)
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            AppColors.accent.opacity(0.15),
                            AppColors.accent.opacity(0.04),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: 400
                    )
                )
                .frame(width: 800, height: 800)
                .blur(radius: 120)
                .offset(y: -320)

            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            AppColors.accentSecondary.opacity(0.08),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: 280
                    )
                )
                .frame(width: 560, height: 560)
                .blur(radius: 80)
                .offset(x: 120, y: 400)

            VStack(spacing: 0) {
                // Top: "Photo Battle — FitCheck AI"
                Text("Photo Battle — FitCheck AI")
                    .font(.system(size: 44, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.top, 72)
                    .padding(.bottom, 48)

                // Middle section: Photo A | VS | Photo B
                HStack(alignment: .top, spacing: 24) {
                    photoColumn(image: imageA, score: scoreA, isWinner: winner == .photoA)
                    vsBadge
                    photoColumn(image: imageB, score: scoreB, isWinner: winner == .photoB)
                }
                .padding(.horizontal, 44)
                .padding(.vertical, 20)

                // Bottom: Advantage line then watermark
                if let adv = advantageText {
                    Text(adv)
                        .font(.system(size: 32, weight: .bold))
                        .foregroundStyle(AppColors.scoreHigh)
                        .padding(.top, 24)
                        .padding(.bottom, 16)
                }

                // Bottom section: Watermark in glass card
                Text("Rated by FitCheck AI")
                    .font(.system(size: 26, weight: .medium))
                    .foregroundStyle(AppColors.mutedText.opacity(0.85))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 28)
                    .background(
                        RoundedRectangle(cornerRadius: 24)
                            .fill(AppColors.cardBackground.opacity(0.85))
                            .overlay(
                                RoundedRectangle(cornerRadius: 24)
                                    .stroke(
                                        LinearGradient(
                                            colors: [
                                                Color.white.opacity(0.12),
                                                Color.white.opacity(0.04)
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        lineWidth: 1
                                    )
                            )
                    )
                    .padding(.horizontal, 44)
                    .padding(.bottom, 70)
            }
        }
        .frame(width: Self.designWidth, height: Self.designHeight)
        .clipShape(RoundedRectangle(cornerRadius: 0))
    }

    private var vsBadge: some View {
        Text("VS")
            .font(.system(size: 22, weight: .bold))
            .foregroundStyle(AppColors.mutedText.opacity(0.9))
            .frame(width: 56, height: 56)
            .background(Color.white.opacity(0.1))
            .clipShape(Circle())
            .overlay(
                Circle()
                    .stroke(Color.white.opacity(0.15), lineWidth: 1)
            )
            .padding(.top, 180)
    }

    private func photoColumn(image: UIImage, score: Double, isWinner: Bool) -> some View {
        VStack(spacing: 16) {
            ZStack(alignment: .topTrailing) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 420, height: 560)
                    .clipShape(RoundedRectangle(cornerRadius: 24))
                    .overlay(
                        RoundedRectangle(cornerRadius: 24)
                            .stroke(
                                isWinner ? AppColors.scoreHigh : Color.white.opacity(0.12),
                                lineWidth: isWinner ? 6 : 1
                            )
                    )
                    .shadow(
                        color: isWinner ? AppColors.scoreHigh.opacity(0.5) : .clear,
                        radius: isWinner ? 32 : 0,
                        x: 0,
                        y: 0
                    )
                if isWinner {
                    Text("WINNER")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(AppColors.scoreHigh)
                        .clipShape(Capsule())
                        .padding(16)
                }
            }
            Text(ScoreFormat.display(score))
                .font(.system(size: 44, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Poll-style share card (no winner, no scores — "Let Friends Decide")

/// Shareable poll-style Photo Battle card: A vs B, "Which fit wins?", no AI result. For viral "Let Friends Decide" sharing.
struct PhotoBattlePollShareCardView: View {
    let imageA: UIImage
    let imageB: UIImage

    static let designWidth: CGFloat = 1080
    static let designHeight: CGFloat = 1920

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
                .offset(y: -280)

            VStack(spacing: 0) {
                // Top: Title + prompt
                Text("Photo Battle")
                    .font(.system(size: 48, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.top, 72)
                Text("Which fit wins?")
                    .font(.system(size: 32, weight: .semibold))
                    .foregroundStyle(AppColors.mutedText.opacity(0.95))
                    .padding(.top, 12)
                    .padding(.bottom, 36)

                // Middle: A vs B (no scores, no winner)
                HStack(alignment: .center, spacing: 20) {
                    pollPhotoColumn(image: imageA, label: "A")
                    vsBadge
                    pollPhotoColumn(image: imageB, label: "B")
                }
                .padding(.horizontal, 40)
                .padding(.vertical, 24)

                Spacer(minLength: 24)

                // A or B? prompt
                Text("A or B?")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(.white.opacity(0.9))
                    .padding(.bottom, 20)

                // Bottom: FitCheck AI branding
                Text("FitCheck AI")
                    .font(.system(size: 24, weight: .medium))
                    .foregroundStyle(AppColors.mutedText.opacity(0.8))
                    .padding(.vertical, 24)
                    .padding(.horizontal, 44)
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(AppColors.cardBackground.opacity(0.9))
                            .overlay(
                                RoundedRectangle(cornerRadius: 20)
                                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
                            )
                    )
                    .padding(.horizontal, 44)
                    .padding(.bottom, 64)
            }
        }
        .frame(width: Self.designWidth, height: Self.designHeight)
        .clipShape(RoundedRectangle(cornerRadius: 0))
    }

    private var vsBadge: some View {
        Text("VS")
            .font(.system(size: 24, weight: .bold))
            .foregroundStyle(AppColors.mutedText.opacity(0.9))
            .frame(width: 60, height: 60)
            .background(Color.white.opacity(0.12))
            .clipShape(Circle())
            .overlay(
                Circle()
                    .stroke(Color.white.opacity(0.15), lineWidth: 1)
            )
    }

    private func pollPhotoColumn(image: UIImage, label: String) -> some View {
        VStack(spacing: 12) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: 420, height: 520)
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.25), radius: 16, y: 8)
            Text(label)
                .font(.system(size: 36, weight: .bold))
                .foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity)
    }
}

extension PhotoBattlePollShareCardView {
    /// Renders the poll-style Photo Battle card to a UIImage (1080×1920). No winner or scores.
    static func renderPollShareCard(imageA: UIImage, imageB: UIImage) -> UIImage? {
        let card = PhotoBattlePollShareCardView(imageA: imageA, imageB: imageB)
            .preferredColorScheme(.dark)
        return ViewImageRenderer.render(
            card,
            width: designWidth,
            height: designHeight,
            scale: 1
        )
    }
}

// MARK: - Render to UIImage

extension PhotoBattleShareCardView {
    /// Renders the Photo Battle share card to a UIImage (1080×1920). Returns nil if rendering fails.
    static func renderPhotoBattleShareCard(
        imageA: UIImage,
        imageB: UIImage,
        scoreA: Double,
        scoreB: Double,
        winner: CompareWinner
    ) -> UIImage? {
        let card = PhotoBattleShareCardView(
            imageA: imageA,
            imageB: imageB,
            scoreA: scoreA,
            scoreB: scoreB,
            winner: winner
        )
        .preferredColorScheme(.dark)
        return ViewImageRenderer.render(
            card,
            width: designWidth,
            height: designHeight,
            scale: 1
        )
    }
}

#Preview {
    PhotoBattleShareCardView(
        imageA: UIImage(systemName: "photo.fill") ?? UIImage(),
        imageB: UIImage(systemName: "photo.fill") ?? UIImage(),
        scoreA: 8.7,
        scoreB: 7.4,
        winner: .photoA
    )
    .preferredColorScheme(.dark)
}
