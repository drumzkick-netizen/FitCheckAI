//
//  ShareBattleCardView.swift
//  FitCheckAI
//

import SwiftUI
import UIKit

/// Premium share card for Photo Battle: both photos, scores, winner treatment, score difference, summary line, FitCheckAI branding.
/// Rendered to UIImage via ViewImageRenderer and shared from CompareResultsView.
struct ShareBattleCardView: View {
    let imageA: UIImage
    let imageB: UIImage
    let resultA: AnalysisResult
    let resultB: AnalysisResult
    let winner: CompareWinner

    private static let cardWidth: CGFloat = 400
    private static let photoHeight: CGFloat = 200
    private static let titleSectionHeight: CGFloat = 56
    private static let scoresRowHeight: CGFloat = 52
    private static let scoreDiffHeight: CGFloat = 28
    private static let summarySectionHeight: CGFloat = 52
    private static let categorySectionHeight: CGFloat = 88
    private static let footerHeight: CGFloat = 40
    private static let verticalPadding: CGFloat = 24
    private static let horizontalPadding: CGFloat = 24
    private static let photoCornerRadius: CGFloat = 16
    private static let vsPillSize: CGFloat = 32

    private var hasSubscores: Bool {
        resultA.subscores != nil && resultB.subscores != nil
    }

    private var summaryLine: String {
        let diff = abs(resultA.score - resultB.score)
        if diff < 0.2 {
            return "Both photos scored similarly."
        }
        if resultA.score > resultB.score {
            let strength = resultA.strengths.first ?? "stronger overall presentation"
            return "Photo A wins with \(strength.lowercased())."
        } else {
            let strength = resultB.strengths.first ?? "stronger overall presentation"
            return "Photo B wins with \(strength.lowercased())."
        }
    }

    private var scoreDifference: (diff: Double, winnerScore: Double, loserScore: Double)? {
        guard winner != .tie else { return nil }
        let a = resultA.score
        let b = resultB.score
        let (win, lose) = winner == .photoA ? (a, b) : (b, a)
        return (abs(a - b), win, lose)
    }

    private var totalHeight: CGFloat {
        var h = Self.titleSectionHeight + Self.photoHeight + Self.scoresRowHeight + Self.footerHeight + Self.verticalPadding * 2
        if winner != .tie { h += Self.scoreDiffHeight }
        h += Self.summarySectionHeight
        if hasSubscores { h += Self.categorySectionHeight + 12 }
        return h
    }

    var body: some View {
        VStack(spacing: 0) {
            titleSection
            photosRow
            scoresRow
            if winner != .tie, let diffInfo = scoreDifference {
                scoreDifferenceLine(diff: diffInfo.diff, winnerScore: diffInfo.winnerScore, loserScore: diffInfo.loserScore)
            }
            summarySection
            if hasSubscores, let sA = resultA.subscores, let sB = resultB.subscores {
                categoryComparison(sA: sA, sB: sB)
            }
            Spacer(minLength: 16)
            footer
        }
        .padding(.horizontal, Self.horizontalPadding)
        .padding(.vertical, Self.verticalPadding)
        .frame(width: Self.cardWidth, height: totalHeight)
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
                    lineWidth: 1.5
                )
        )
    }

    private var titleSection: some View {
        VStack(spacing: 4) {
            Text("Photo Battle")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(.white)
            Text(AppBrand.appDisplayName)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(AppColors.mutedText.opacity(0.85))
        }
        .frame(height: Self.titleSectionHeight)
        .frame(maxWidth: .infinity)
    }

    private var photosRow: some View {
        HStack(alignment: .center, spacing: 10) {
            battlePhoto(image: imageA, label: "Photo A", isWinner: winner == .photoA)
            vsPill
            battlePhoto(image: imageB, label: "Photo B", isWinner: winner == .photoB)
        }
        .frame(height: Self.photoHeight)
    }

    private var vsPill: some View {
        Text("VS")
            .font(.system(size: 11, weight: .bold))
            .foregroundStyle(AppColors.mutedText.opacity(0.9))
            .frame(width: Self.vsPillSize, height: Self.vsPillSize)
            .background(Color.white.opacity(0.08))
            .clipShape(Circle())
            .overlay(
                Circle()
                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
            )
    }

    private func battlePhoto(image: UIImage, label: String, isWinner: Bool) -> some View {
        ZStack(alignment: .topTrailing) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(maxWidth: .infinity)
                .frame(height: Self.photoHeight)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: Self.photoCornerRadius))
                .overlay(
                    RoundedRectangle(cornerRadius: Self.photoCornerRadius)
                        .stroke(
                            isWinner ? AppColors.scoreHigh : Color.white.opacity(0.12),
                            lineWidth: isWinner ? 4 : 1
                        )
                )
                .shadow(color: isWinner ? AppColors.scoreHigh.opacity(0.5) : Color.black.opacity(0.35), radius: isWinner ? 14 : 8, x: 0, y: 4)
            if isWinner {
                winsBadge
            }
            Text(label)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.black.opacity(0.55))
                .clipShape(Capsule())
                .padding(8)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }

    private var winsBadge: some View {
        Text("Wins")
            .font(.system(size: 10, weight: .bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(AppColors.scoreHigh)
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(Color.white.opacity(0.25), lineWidth: 1)
            )
            .padding(8)
    }

    private var scoresRow: some View {
        HStack(spacing: 10) {
            scoreCell(score: resultA.score, label: "A", isWinner: winner == .photoA)
            scoreCell(score: resultB.score, label: "B", isWinner: winner == .photoB)
        }
        .frame(height: Self.scoresRowHeight)
        .padding(.top, 12)
    }

    private func scoreCell(score: Double, label: String, isWinner: Bool) -> some View {
        VStack(spacing: 2) {
            Text(ScoreFormat.display(score))
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(isWinner ? AppColors.scoreHigh : .white)
            Text("Photo \(label)")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(AppColors.mutedText)
            if isWinner {
                Text("Wins")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(AppColors.scoreHigh.opacity(0.95))
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func scoreDifferenceLine(diff: Double, winnerScore: Double, loserScore: Double) -> some View {
        Text(String(format: "Wins by %.1f  ·  %.1f vs %.1f", diff, winnerScore, loserScore))
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(AppColors.scoreHigh.opacity(0.95))
            .frame(height: Self.scoreDiffHeight)
            .frame(maxWidth: .infinity)
    }

    private var summarySection: some View {
        HStack(spacing: 6) {
            Image(systemName: "lightbulb.fill")
                .font(.system(size: 10))
                .foregroundStyle(AppColors.scoreHigh.opacity(0.9))
            Text(summaryLine)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(AppColors.mutedText)
                .lineLimit(2)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity)
        .frame(height: Self.summarySectionHeight)
        .background(Color.white.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        )
    }

    private func categoryComparison(sA: AnalysisSubscores, sB: AnalysisSubscores) -> some View {
        let categories: [(String, Double, Double)] = [
            ("Composition", sA.composition, sB.composition),
            ("Lighting", sA.lighting, sB.lighting),
            ("Presentation", sA.presentation, sB.presentation),
            ("Purpose Fit", sA.purposeFit, sB.purposeFit),
        ]
        return VStack(spacing: 6) {
            ForEach(Array(categories.enumerated()), id: \.offset) { _, item in
                HStack(spacing: 8) {
                    Text(item.0)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(AppColors.mutedText)
                        .frame(width: 72, alignment: .leading)
                    Text(ScoreFormat.display(item.1))
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(item.1 >= item.2 ? AppColors.scoreHigh.opacity(0.95) : AppColors.mutedText)
                        .frame(width: 28, alignment: .center)
                    categoryBar(a: item.1, b: item.2)
                    Text(ScoreFormat.display(item.2))
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(item.2 >= item.1 ? AppColors.scoreHigh.opacity(0.95) : AppColors.mutedText)
                        .frame(width: 28, alignment: .center)
                }
            }
        }
        .padding(.horizontal, 4)
        .padding(.top, 10)
    }

    private func categoryBar(a: Double, b: Double) -> some View {
        GeometryReader { geo in
            let w = geo.size.width
            let total = a + b
            let leftFrac = total > 0 ? (a / total) : 0.5
            let leftW = max(2, w * leftFrac)
            let rightW = max(2, w - leftW)
            HStack(spacing: 0) {
                Rectangle()
                    .fill(a >= b ? AppColors.scoreHigh.opacity(0.85) : AppColors.mutedText.opacity(0.35))
                    .frame(width: leftW)
                Rectangle()
                    .fill(b >= a ? AppColors.scoreHigh.opacity(0.85) : AppColors.mutedText.opacity(0.35))
                    .frame(width: rightW)
            }
        }
        .frame(height: 4)
        .clipShape(RoundedRectangle(cornerRadius: 2))
    }

    private var footer: some View {
        Text(AppBrand.appDisplayName)
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(AppColors.mutedText.opacity(0.7))
            .frame(height: Self.footerHeight)
            .frame(maxWidth: .infinity)
    }

    /// Fixed size for rendering. Use this when calling ViewImageRenderer. Pass isTie: true when winner == .tie so height matches the view.
    static func cardSize(hasSubscores: Bool, isTie: Bool = false) -> (width: CGFloat, height: CGFloat) {
        var h: CGFloat = titleSectionHeight + photoHeight + scoresRowHeight + footerHeight + verticalPadding * 2
        if !isTie { h += scoreDiffHeight }
        h += summarySectionHeight
        if hasSubscores { h += categorySectionHeight + 12 }
        return (cardWidth, h)
    }
}

#Preview {
    let resultA = AnalysisResult(
        score: 8.2,
        subscores: AnalysisSubscores(composition: 8.0, lighting: 8.4, presentation: 8.1, purposeFit: 8.3),
        strengths: ["Strong composition and lighting"],
        improvements: [],
        suggestions: []
    )
    let resultB = AnalysisResult(
        score: 7.6,
        subscores: AnalysisSubscores(composition: 7.5, lighting: 7.8, presentation: 7.4, purposeFit: 7.6),
        strengths: ["Good lighting"],
        improvements: [],
        suggestions: []
    )
    let img = UIImage(systemName: "photo.fill") ?? UIImage()
    ShareBattleCardView(
        imageA: img,
        imageB: img,
        resultA: resultA,
        resultB: resultB,
        winner: .photoA
    )
    .preferredColorScheme(.dark)
}
