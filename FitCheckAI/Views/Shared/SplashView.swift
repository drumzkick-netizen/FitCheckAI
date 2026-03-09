//
//  SplashView.swift
//  FitCheckAI
//
//  In-app splash shown briefly at launch. Dark background, app name, tagline, brand mark.
//  Fade-in on appear; parent handles dismissal and fade-out.
//

import SwiftUI

private let splashFadeInDuration: Double = 0.4

struct SplashView: View {
    /// How long the app root should show the splash before transitioning to main content.
    static let displayDuration: Double = 1.25
    @State private var opacity: Double = 0

    var body: some View {
        ZStack {
            AppColors.background.ignoresSafeArea()

            RadialGradient(
                colors: [
                    AppColors.accent.opacity(0.14),
                    AppColors.accent.opacity(0.04),
                    Color.clear
                ],
                center: .center,
                startRadius: 40,
                endRadius: 220
            )
            .ignoresSafeArea()

            VStack(spacing: 20) {
                BrandMarkView(size: 80, lineWidth: 5, showGlow: true)

                Text(AppBrand.appDisplayName)
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)

                Text(AppBrand.appTagline)
                    .font(.subheadline)
                    .foregroundStyle(AppColors.mutedText)
            }
            .padding(.horizontal, 32)
            .opacity(opacity)
        }
        .preferredColorScheme(.dark)
        .onAppear {
            withAnimation(.easeOut(duration: splashFadeInDuration)) {
                opacity = 1
            }
        }
    }
}

#Preview {
    SplashView()
        .preferredColorScheme(.dark)
}
