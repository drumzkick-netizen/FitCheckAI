//
//  BrandMarkView.swift
//  FitCheckAI
//
//  Reusable brand mark: score-ring–inspired circle with subtle glow.
//  Use on splash, Settings, or Home for light branding.
//

import SwiftUI

struct BrandMarkView: View {
    var size: CGFloat = 72
    var lineWidth: CGFloat = 4
    var showGlow: Bool = true

    var body: some View {
        ZStack {
            if showGlow {
                Circle()
                    .stroke(AppColors.accent.opacity(0.35), lineWidth: lineWidth + 2)
                    .frame(width: size + 8, height: size + 8)
                    .blur(radius: 8)
            }
            Circle()
                .stroke(AppColors.cardBackgroundElevated, lineWidth: lineWidth)
                .frame(width: size, height: size)
            Circle()
                .trim(from: 0, to: 0.75)
                .stroke(AppColors.accent, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .frame(width: size, height: size)
                .rotationEffect(.degrees(-90))
        }
    }
}

#Preview {
    ZStack {
        AppColors.background.ignoresSafeArea()
        BrandMarkView(size: 88, lineWidth: 5)
    }
    .preferredColorScheme(.dark)
}
