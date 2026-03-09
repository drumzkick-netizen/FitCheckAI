//
//  ScoreBreakdownRow.swift
//  FitCheckAI
//

import SwiftUI

/// Single row for score breakdown: label on left, score on right.
struct ScoreBreakdownRow: View {
    let label: String
    let score: Double

    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.white)
            Spacer()
            Text(ScoreFormat.display(score))
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(AppColors.mutedText)
        }
        .padding(.vertical, 8)
    }
}

#Preview {
    VStack(spacing: 0) {
        ScoreBreakdownRow(label: "Composition", score: 8.5)
        ScoreBreakdownRow(label: "Lighting", score: 7.8)
        ScoreBreakdownRow(label: "Presentation", score: 8.7)
        ScoreBreakdownRow(label: "Purpose Fit", score: 8.1)
    }
    .padding()
    .background(AppColors.cardBackground)
    .preferredColorScheme(.dark)
}
