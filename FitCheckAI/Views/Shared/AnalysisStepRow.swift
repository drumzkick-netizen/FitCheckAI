//
//  AnalysisStepRow.swift
//  FitCheckAI
//

import SwiftUI

struct AnalysisStepRow: View {
    let title: String
    var isComplete: Bool = false
    var isActive: Bool = false

    @State private var pulsePhase: Double = 0

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                if isComplete {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(AppColors.scoreHigh)
                } else if isActive {
                    ProgressView()
                        .scaleEffect(0.88)
                        .tint(AppColors.accent)
                } else {
                    Image(systemName: "circle")
                        .font(.system(size: 18))
                        .foregroundStyle(AppColors.mutedText.opacity(0.5))
                }
            }
            .frame(width: 24, height: 24, alignment: .center)

            Text(title)
                .font(.subheadline)
                .fontWeight(isComplete || isActive ? .medium : .regular)
                .foregroundStyle(isComplete || isActive ? .white : AppColors.mutedText)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 4)
        .opacity(pendingOpacity)
        .onAppear {
            if isActive {
                withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                    pulsePhase = 1
                }
            }
        }
        .onChange(of: isActive) { _, active in
            if active {
                withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                    pulsePhase = 1
                }
            } else {
                pulsePhase = 0
            }
        }
    }

    private var pendingOpacity: Double {
        if isComplete { return 1 }
        if isActive { return 0.88 + 0.12 * pulsePhase }
        return 0.72
    }
}

#Preview {
    ZStack {
        AppColors.background.ignoresSafeArea()
        VStack(alignment: .leading, spacing: 4) {
            AnalysisStepRow(title: "Photo quality", isActive: true)
            AnalysisStepRow(title: "Composition", isComplete: true)
            AnalysisStepRow(title: "Presentation")
        }
        .padding()
    }
    .preferredColorScheme(.dark)
}
