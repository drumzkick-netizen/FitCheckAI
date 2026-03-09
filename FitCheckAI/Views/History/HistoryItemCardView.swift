//
//  HistoryItemCardView.swift
//  FitCheckAI
//

import SwiftUI
import UIKit

private let thumbnailSize: CGFloat = 68
private let scoreRingSize: CGFloat = 52
private let scoreRingLineWidth: CGFloat = 4

struct HistoryItemCardView: View {
    let item: PhotoAnalysis

    private var insight: ScoreInsight {
        ScoreInsights.insight(for: item.result.score)
    }

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            thumbnail
            mainContent
            scoreSection
            Image(systemName: "chevron.right")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(AppColors.mutedText.opacity(0.8))
        }
        .padding(.vertical, 4)
        .glassCard(padding: 16, cornerRadius: 24)
    }

    private var thumbnail: some View {
        Group {
            if let uiImage = UIImage(data: item.imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
            } else {
                Rectangle()
                    .fill(AppColors.cardBackgroundElevated)
            }
        }
        .frame(width: thumbnailSize, height: thumbnailSize)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }

    private var mainContent: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Analysis")
                .font(.caption2)
                .fontWeight(.medium)
                .foregroundStyle(AppColors.mutedText.opacity(0.9))
            Text(item.purpose.rawValue.capitalized)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(.white)
            Text(item.date, style: .date)
                .font(.caption)
                .foregroundStyle(AppColors.mutedText)
            if !insight.rankLabel.isEmpty {
                Text(insight.rankLabel)
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundStyle(AppColors.mutedText.opacity(0.85))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var scoreSection: some View {
        ScoreRingView(
            score: item.result.score,
            size: scoreRingSize,
            lineWidth: scoreRingLineWidth,
            animateOnAppear: false
        )
    }
}

#Preview {
    ZStack {
        AppColors.background.ignoresSafeArea()
        HistoryItemCardView(
            item: PhotoAnalysis(
                imageData: Data(),
                purpose: .outfit,
                result: AnalysisResult(
                    score: 8.2,
                    subscores: AnalysisSubscores(composition: 8, lighting: 8.4, presentation: 8.1, purposeFit: 8.2),
                    strengths: ["Good lighting"],
                    improvements: ["Background"],
                    suggestions: ["Try crop"]
                ),
                date: Date()
            )
        )
        .padding()
    }
    .preferredColorScheme(.dark)
}
