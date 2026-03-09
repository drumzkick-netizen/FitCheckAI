//
//  HistoryDetailView.swift
//  FitCheckAI
//

import SwiftUI
import UIKit

struct HistoryDetailView: View {
    @EnvironmentObject private var historyViewModel: HistoryViewModel
    @Environment(\.dismiss) private var dismiss

    let item: PhotoAnalysis

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                imageSection
                metaSection
                scoreSection
                sectionBlock(title: "Strengths", items: item.result.strengths, icon: "plus.circle.fill")
                sectionBlock(title: "Improvements", items: item.result.improvements, icon: "arrow.up.circle.fill")
                sectionBlock(title: "Suggestions", items: item.result.suggestions, icon: "lightbulb.fill")
            }
            .padding()
            .padding(.bottom, 32)
        }
        .background(AmbientGlowBackground())
        .navigationTitle("Past Analysis")
        .navigationBarTitleDisplayMode(.inline)
        .preferredColorScheme(.dark)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(role: .destructive) {
                    historyViewModel.deleteAnalysis(id: item.id)
                    dismiss()
                } label: {
                    Label("Remove", systemImage: "trash")
                }
            }
        }
    }

    private var imageSection: some View {
        Group {
            if let uiImage = UIImage(data: item.imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 260)
                    .frame(maxWidth: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18)
                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                    )
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var metaSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 10) {
                PurposeBadgeView(text: PurposeBadge.label(for: item.purpose))
                Text(item.purpose.rawValue.capitalized)
                    .font(.headline)
                    .foregroundStyle(.white)
            }
            Text(item.date, style: .date)
                .font(.subheadline)
                .foregroundStyle(AppColors.mutedText)
        }
    }

    private var scoreSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(ScoreFormat.display(item.result.score))
                    .font(.system(size: 42, weight: .bold))
                    .foregroundStyle(.white)
                Text("score")
                    .font(.subheadline)
                    .foregroundStyle(AppColors.mutedText)
            }
            Text(FitScoreShareTier.label(for: item.result.score))
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(AppColors.scoreColor(for: item.result.score))
        }
    }

    private func sectionBlock(title: String, items: [String], icon: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)
                .foregroundStyle(.white)
            if items.isEmpty {
                Text("None")
                    .font(.subheadline)
                    .foregroundStyle(AppColors.mutedText)
            } else {
                ForEach(items, id: \.self) { s in
                    Label(s, systemImage: icon)
                        .font(.subheadline)
                        .foregroundStyle(AppColors.mutedText)
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        HistoryDetailView(
            item: PhotoAnalysis(
                imageData: Data(),
                purpose: .outfit,
                result: AnalysisResult(score: 8.2, subscores: AnalysisSubscores(composition: 8.0, lighting: 8.4, presentation: 8.1, purposeFit: 8.2), strengths: ["Good lighting"], improvements: ["Background"], suggestions: ["Try crop"]),
                date: Date()
            )
        )
        .environmentObject(HistoryViewModel())
    }
}
