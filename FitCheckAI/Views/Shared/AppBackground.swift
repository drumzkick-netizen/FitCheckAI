//
//  AppBackground.swift
//  FitCheckAI
//

import SwiftUI

/// Reusable global background: dark gradient base with subtle purple and blue glow accents.
/// Use at the root so all screens share the same premium background when they don’t override it.
struct AppBackground: View {
    private var baseGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 0.05, green: 0.05, blue: 0.1),
                AppColors.background,
                Color(red: 0.06, green: 0.06, blue: 0.14),
                Color(red: 0.04, green: 0.04, blue: 0.1)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    var body: some View {
        ZStack {
            baseGradient

            // Purple glow accent (top)
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            AppColors.accent.opacity(0.22),
                            AppColors.accent.opacity(0.08),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: 240
                    )
                )
                .frame(width: 480, height: 480)
                .blur(radius: 90)
                .offset(x: 0, y: -340)

            // Subtle blue glow accent (bottom right)
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color(red: 0.2, green: 0.45, blue: 0.9).opacity(0.12),
                            Color(red: 0.2, green: 0.5, blue: 0.85).opacity(0.04),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: 180
                    )
                )
                .frame(width: 360, height: 360)
                .blur(radius: 70)
                .offset(x: 100, y: 280)

            // Secondary purple radial (bottom left)
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            AppColors.accentSecondary.opacity(0.1),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: 160
                    )
                )
                .frame(width: 320, height: 320)
                .blur(radius: 60)
                .offset(x: -80, y: 400)
        }
        .ignoresSafeArea()
    }
}

#Preview {
    AppBackground()
        .preferredColorScheme(.dark)
}
