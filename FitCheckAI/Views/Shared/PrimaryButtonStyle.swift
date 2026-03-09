//
//  PrimaryButtonStyle.swift
//  FitCheckAI
//

import SwiftUI

struct PrimaryButtonStyle: ButtonStyle {
    var withGlow: Bool = false

    @State private var glowOpacity: Double = 0.4

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                Group {
                    if withGlow {
                        AnimatedGradientButtonBackground()
                    } else {
                        RoundedRectangle(cornerRadius: 14)
                            .fill(AppGradients.primary)
                    }
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(
                        withGlow ? AppColors.accent.opacity(glowOpacity) : Color.clear,
                        lineWidth: withGlow ? 1.5 : 0
                    )
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .opacity(configuration.isPressed ? 0.92 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
            .onAppear {
                if withGlow {
                    withAnimation(.easeInOut(duration: 2.8).repeatForever(autoreverses: true)) {
                        glowOpacity = 0.75
                    }
                }
            }
    }
}
