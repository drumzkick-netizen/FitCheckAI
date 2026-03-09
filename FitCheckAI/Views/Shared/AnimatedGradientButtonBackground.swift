//
//  AnimatedGradientButtonBackground.swift
//  FitCheckAI
//

import SwiftUI

private let gradientShiftDuration: Double = 4.0

struct AnimatedGradientButtonBackground: View {
    @State private var phase: CGFloat = 0

    var body: some View {
        RoundedRectangle(cornerRadius: 14)
            .fill(
                LinearGradient(
                    colors: [
                        AppColors.accent,
                        AppColors.accentSecondary,
                        AppColors.accent.opacity(0.9)
                    ],
                    startPoint: UnitPoint(x: 0.2 + 0.1 * phase, y: 0.2),
                    endPoint: UnitPoint(x: 0.8 + 0.1 * (1 - phase), y: 0.8)
                )
            )
            .onAppear {
                withAnimation(.easeInOut(duration: gradientShiftDuration).repeatForever(autoreverses: true)) {
                    phase = 1
                }
            }
    }
}
