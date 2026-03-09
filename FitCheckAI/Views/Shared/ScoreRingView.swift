//
//  ScoreRingView.swift
//  FitCheckAI
//

import SwiftUI

struct ScoreRingView: View {
    let score: Double
    var size: CGFloat = 120
    var lineWidth: CGFloat = 12
    var animateOnAppear: Bool = false
    /// When set with animateOnAppear, uses this duration and easeOut for the score count-up. e.g. 1.0 for a 1s reveal.
    var revealDuration: Double? = nil
    /// Ring draw duration when animateOnAppear is true. Default 1.2s.
    var ringRevealDuration: Double = 1.2

    @State private var displayedScore: Double = 0
    @State private var ringProgress: CGFloat = 0

    private var scoreColor: Color {
        switch score {
        case 9...10: return AppColors.scoreHigh
        case 7..<9: return AppColors.scoreMid
        case 5..<7: return AppColors.scoreLow
        default: return AppColors.scorePoor
        }
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(AppColors.cardBackgroundElevated, lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: ringProgress)
                .stroke(scoreColor, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.easeOut(duration: ringRevealDuration), value: ringProgress)
            Text(ScoreFormat.display(displayedScore))
                .font(.system(size: size * 0.28, weight: .bold))
                .foregroundStyle(.white)
        }
        .frame(width: size, height: size)
        .onAppear {
            if animateOnAppear {
                displayedScore = 0
                ringProgress = 0
                let scoreDuration = revealDuration ?? 1.0
                withAnimation(.easeOut(duration: scoreDuration)) {
                    displayedScore = score
                }
                withAnimation(.easeOut(duration: ringRevealDuration)) {
                    ringProgress = min(1, max(0, CGFloat(score / 10)))
                }
            } else {
                displayedScore = score
                ringProgress = min(1, max(0, CGFloat(score / 10)))
            }
        }
        .onChange(of: score) { _, newValue in
            if !animateOnAppear {
                displayedScore = newValue
                ringProgress = min(1, max(0, CGFloat(newValue / 10)))
            }
        }
    }
}

#Preview {
    ZStack {
        AppColors.background.ignoresSafeArea()
        ScoreRingView(score: 8.2, animateOnAppear: true)
    }
    .preferredColorScheme(.dark)
}
