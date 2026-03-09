//
//  GlowCard.swift
//  FitCheckAI
//

import SwiftUI

// MARK: - Premium card glow gradient (purple → blue)
private let glowCardGradient = LinearGradient(
    colors: [
        Color(red: 0.5, green: 0.35, blue: 0.95),
        Color(red: 0.25, green: 0.45, blue: 0.95)
    ],
    startPoint: .topLeading,
    endPoint: .bottomTrailing
)

/// Reusable premium glass + glow card used across the app for visual consistency.
/// Uses rounded corners, ultraThinMaterial, subtle border, blurred gradient glow, and soft shadow.
struct GlowCard<Content: View>: View {
    let padding: CGFloat
    let cornerRadius: CGFloat
    let content: Content

    init(
        padding: CGFloat = 20,
        cornerRadius: CGFloat = 24,
        @ViewBuilder content: () -> Content
    ) {
        self.padding = padding
        self.cornerRadius = cornerRadius
        self.content = content()
    }

    var body: some View {
        ZStack {
            // Blurred gradient glow behind the card
            RoundedRectangle(cornerRadius: cornerRadius + 4)
                .fill(glowCardGradient)
                .blur(radius: 40)
                .opacity(0.5)

            content
                .padding(padding)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.35), radius: 20, y: 12)
        }
    }
}
