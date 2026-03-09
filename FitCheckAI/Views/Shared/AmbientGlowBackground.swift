//
//  AmbientGlowBackground.swift
//  FitCheckAI
//

import SwiftUI

struct AmbientGlowBackground: View {
    var body: some View {
        ZStack {
            AppColors.background

            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            AppColors.accent.opacity(0.12),
                            AppColors.accent.opacity(0.04),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: 180
                    )
                )
                .frame(width: 400, height: 400)
                .blur(radius: 60)
                .offset(x: 0, y: -280)

            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            AppColors.accentSecondary.opacity(0.06),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: 120
                    )
                )
                .frame(width: 300, height: 300)
                .blur(radius: 50)
                .offset(x: 80, y: 200)

            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color(red: 0.2, green: 0.6, blue: 0.8).opacity(0.05),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: 100
                    )
                )
                .frame(width: 280, height: 280)
                .blur(radius: 45)
                .offset(x: -60, y: 320)
        }
        .ignoresSafeArea()
    }
}

#Preview {
    AmbientGlowBackground()
        .preferredColorScheme(.dark)
}
