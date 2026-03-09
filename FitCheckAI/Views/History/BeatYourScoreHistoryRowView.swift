//
//  BeatYourScoreHistoryRowView.swift
//  FitCheckAI
//

import SwiftUI
import UIKit

struct BeatYourScoreHistoryRowView: View {
    let result: BeatYourScoreResult

    var body: some View {
        HStack(spacing: 14) {
            thumbnailsSection
            mainContent
            scoresSection
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(AppColors.mutedText.opacity(0.8))
        }
        .padding(.vertical, 4)
        .glassCard(padding: 16, cornerRadius: 24)
    }

    private var thumbnailsSection: some View {
        HStack(spacing: 6) {
            thumbnailBlock(data: result.originalImageData)
            Text("→")
                .font(.caption2)
                .fontWeight(.bold)
                .foregroundStyle(AppColors.mutedText)
            thumbnailBlock(data: result.newImageData, highlight: result.improved)
        }
    }

    private func thumbnailBlock(data: Data, highlight: Bool = false) -> some View {
        Group {
            if let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
            } else {
                Rectangle()
                    .fill(AppColors.cardBackground)
            }
        }
        .frame(width: 44, height: 44)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(highlight ? AppColors.scoreHigh.opacity(0.6) : Color.white.opacity(0.06), lineWidth: highlight ? 2 : 1)
        )
    }

    private var mainContent: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Beat Your Score")
                .font(.caption2)
                .fontWeight(.medium)
                .foregroundStyle(AppColors.mutedText.opacity(0.9))
            Text(result.date, style: .date)
                .font(.caption)
                .foregroundStyle(AppColors.mutedText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var scoresSection: some View {
        VStack(alignment: .trailing, spacing: 4) {
            if result.improved {
                Text(String(format: "+%.1f", result.scoreDifference))
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundStyle(AppColors.scoreHigh)
            }
            Text("\(ScoreFormat.display(result.originalScore)) → \(ScoreFormat.display(result.newScore))")
                .font(.caption)
                .foregroundStyle(AppColors.mutedText)
        }
    }
}
