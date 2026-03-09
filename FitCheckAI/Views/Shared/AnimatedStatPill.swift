//
//  AnimatedStatPill.swift
//  FitCheckAI
//

import SwiftUI

struct AnimatedStatPill: View {
    let text: String
    var delay: Double = 0

    @State private var isVisible = false

    var body: some View {
        Text(text)
            .font(.caption)
            .fontWeight(.medium)
            .foregroundStyle(AppColors.mutedText)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(AppColors.cardBackground)
            .clipShape(Capsule())
            .scaleEffect(isVisible ? 1 : 0.92)
            .opacity(isVisible ? 1 : 0)
            .onAppear {
                withAnimation(AppMotion.standardEase.delay(delay)) {
                    isVisible = true
                }
            }
    }
}
