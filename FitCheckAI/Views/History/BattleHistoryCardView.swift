//
//  BattleHistoryCardView.swift
//  FitCheckAI
//

import SwiftUI
import UIKit

private let thumbnailSize: CGFloat = 58
private let vsFontSize: CGFloat = 11

struct BattleHistoryCardView: View {
    let battle: PhotoBattleResult

    private var winnerLabel: String {
        switch battle.winner {
        case .photoA: return "Photo A won"
        case .photoB: return "Photo B won"
        case .tie: return "Tie"
        }
    }

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            thumbnailsSection
            mainContent
            scoresSection
            Image(systemName: "chevron.right")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(AppColors.mutedText.opacity(0.8))
        }
        .padding(.vertical, 4)
        .glassCard(padding: 16, cornerRadius: 24)
    }

    private var thumbnailsSection: some View {
        HStack(spacing: 8) {
            thumbnailBlock(data: battle.imageAData, label: "A", isWinner: battle.winner == .photoA)
            Text("vs")
                .font(.system(size: vsFontSize, weight: .bold))
                .foregroundStyle(AppColors.mutedText.opacity(0.8))
            thumbnailBlock(data: battle.imageBData, label: "B", isWinner: battle.winner == .photoB)
        }
    }

    private func thumbnailBlock(data: Data, label: String, isWinner: Bool) -> some View {
        VStack(spacing: 4) {
            Group {
                if let uiImage = UIImage(data: data) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                } else {
                    Rectangle()
                        .fill(AppColors.cardBackgroundElevated)
                }
            }
            .frame(width: thumbnailSize, height: thumbnailSize)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isWinner ? AppColors.scoreHigh.opacity(0.7) : Color.white.opacity(0.08), lineWidth: isWinner ? 2 : 1)
            )
            Text(label)
                .font(.caption2)
                .fontWeight(.semibold)
                .foregroundStyle(isWinner ? AppColors.scoreHigh : AppColors.mutedText)
        }
        .frame(width: thumbnailSize + 4)
    }

    private var mainContent: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Photo Battle")
                .font(.caption2)
                .fontWeight(.medium)
                .foregroundStyle(AppColors.mutedText.opacity(0.9))
            Text(winnerLabel)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(.white)
            Text(battle.date, style: .date)
                .font(.caption)
                .foregroundStyle(AppColors.mutedText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var scoresSection: some View {
        VStack(spacing: 4) {
            HStack(spacing: 6) {
                scorePill(score: battle.scoreA, isWinner: battle.winner == .photoA)
                Text("–")
                    .font(.caption)
                    .foregroundStyle(AppColors.mutedText)
                scorePill(score: battle.scoreB, isWinner: battle.winner == .photoB)
            }
            Text("A vs B")
                .font(.caption2)
                .foregroundStyle(AppColors.mutedText.opacity(0.8))
        }
    }

    private func scorePill(score: Double, isWinner: Bool) -> some View {
        Text(ScoreFormat.display(score))
            .font(.subheadline)
            .fontWeight(.bold)
            .foregroundStyle(isWinner ? AppColors.scoreHigh : .white)
            .frame(minWidth: 36, alignment: .center)
    }
}

#Preview {
    ZStack {
        AppColors.background.ignoresSafeArea()
        BattleHistoryCardView(
            battle: PhotoBattleResult(
                imageAData: Data(),
                imageBData: Data(),
                scoreA: 8.2,
                scoreB: 7.5,
                winner: .photoA
            )
        )
        .padding()
    }
    .preferredColorScheme(.dark)
}
