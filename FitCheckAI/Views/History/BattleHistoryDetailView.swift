//
//  BattleHistoryDetailView.swift
//  FitCheckAI
//

import SwiftUI
import UIKit

struct BattleHistoryDetailView: View {
    @EnvironmentObject private var historyViewModel: HistoryViewModel
    @Environment(\.dismiss) private var dismiss

    let battle: PhotoBattleResult

    private var winnerLabel: String {
        switch battle.winner {
        case .photoA: return "Photo A won"
        case .photoB: return "Photo B won"
        case .tie: return "Tie"
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                headerSection
                photosSection
                scoresSection
            }
            .padding()
            .padding(.bottom, 32)
        }
        .background(AmbientGlowBackground())
        .navigationTitle("Photo Battle")
        .navigationBarTitleDisplayMode(.inline)
        .preferredColorScheme(.dark)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(role: .destructive) {
                    historyViewModel.deleteBattle(id: battle.id)
                    dismiss()
                } label: {
                    Label("Remove", systemImage: "trash")
                }
            }
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Photo Battle")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(AppColors.mutedText)
            Text(winnerLabel)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(.white)
            Text(battle.date, style: .date)
                .font(.subheadline)
                .foregroundStyle(AppColors.mutedText)
        }
    }

    private var photosSection: some View {
        HStack(spacing: 12) {
            photoCard(data: battle.imageAData, label: "Photo A", isWinner: battle.winner == .photoA)
            photoCard(data: battle.imageBData, label: "Photo B", isWinner: battle.winner == .photoB)
        }
    }

    private func photoCard(data: Data, label: String, isWinner: Bool) -> some View {
        VStack(spacing: 10) {
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
            .frame(height: 200)
            .frame(maxWidth: .infinity)
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isWinner ? AppColors.scoreHigh.opacity(0.8) : Color.white.opacity(0.08), lineWidth: isWinner ? 2.5 : 1)
            )
            Text(label)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(isWinner ? .white : AppColors.mutedText)
        }
        .frame(maxWidth: .infinity)
    }

    private var scoresSection: some View {
        HStack(spacing: 24) {
            scoreBlock(score: battle.scoreA, label: "Photo A", isWinner: battle.winner == .photoA)
            scoreBlock(score: battle.scoreB, label: "Photo B", isWinner: battle.winner == .photoB)
        }
        .frame(maxWidth: .infinity)
        .glassCard(padding: 20, cornerRadius: 24)
    }

    private func scoreBlock(score: Double, label: String, isWinner: Bool) -> some View {
        VStack(spacing: 8) {
            Text(ScoreFormat.display(score))
                .font(.title)
                .fontWeight(.bold)
                .foregroundStyle(isWinner ? AppColors.scoreHigh : .white)
            Text(label)
                .font(.caption)
                .foregroundStyle(AppColors.mutedText)
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    NavigationStack {
        BattleHistoryDetailView(
            battle: PhotoBattleResult(
                imageAData: Data(),
                imageBData: Data(),
                scoreA: 8.2,
                scoreB: 7.5,
                winner: .photoA
            )
        )
        .environmentObject(HistoryViewModel())
    }
}
