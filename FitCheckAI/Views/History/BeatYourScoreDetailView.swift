//
//  BeatYourScoreDetailView.swift
//  FitCheckAI
//

import SwiftUI
import UIKit

/// Read-only detail view for a saved Beat Your Score comparison.
struct BeatYourScoreDetailView: View {
    @EnvironmentObject private var historyViewModel: HistoryViewModel
    @Environment(\.dismiss) private var dismiss

    let result: BeatYourScoreResult

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                headerSection
                comparisonSection
            }
            .padding(20)
            .padding(.bottom, 40)
        }
        .background(AmbientGlowBackground())
        .navigationTitle("Beat Your Score")
        .navigationBarTitleDisplayMode(.inline)
        .preferredColorScheme(.dark)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(role: .destructive) {
                    historyViewModel.deleteBeatYourScore(id: result.id)
                    dismiss()
                } label: {
                    Label("Remove", systemImage: "trash")
                }
            }
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(result.date, style: .date)
                .font(.subheadline)
                .foregroundStyle(AppColors.mutedText)
            Text(result.improved ? "You Improved Your Fit" : (result.scoreDifference == 0 ? "It's a Tie" : "Original Fit Wins"))
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(result.improved ? AppColors.scoreHigh : .white)
            if result.improved {
                Text(String(format: "+%.1f Improvement", result.scoreDifference))
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(AppColors.scoreHigh)
            } else if result.scoreDifference != 0 {
                Text(String(format: "%.1f Lower Score", result.scoreDifference))
                    .font(.subheadline)
                    .foregroundStyle(AppColors.mutedText)
            }
        }
    }

    private var comparisonSection: some View {
        HStack(alignment: .top, spacing: 16) {
            comparisonCard(
                imageData: result.originalImageData,
                label: "Original",
                score: result.originalScore,
                isWinner: !result.improved && result.scoreDifference != 0
            )
            comparisonCard(
                imageData: result.newImageData,
                label: "New",
                score: result.newScore,
                isWinner: result.improved
            )
        }
    }

    private func comparisonCard(imageData: Data, label: String, score: Double, isWinner: Bool) -> some View {
        VStack(spacing: 10) {
            Group {
                if let uiImage = UIImage(data: imageData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                } else {
                    Rectangle()
                        .fill(AppColors.cardBackground)
                }
            }
            .frame(height: 200)
            .frame(maxWidth: .infinity)
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isWinner ? AppColors.scoreHigh.opacity(0.8) : Color.white.opacity(0.08), lineWidth: isWinner ? 2.5 : 1)
            )
            Text(label)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(AppColors.mutedText)
            Text(ScoreFormat.display(score))
                .font(.title3)
                .fontWeight(.bold)
                .foregroundStyle(isWinner ? AppColors.scoreHigh : .white)
        }
        .frame(maxWidth: .infinity)
        .padding(16)
        .glassCard(padding: 16, cornerRadius: 20)
    }
}
