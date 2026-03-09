//
//  GlowPulseModifier.swift
//  FitCheckAI
//

import SwiftUI

private let glowPulseDuration: Double = 3.0

struct GlowPulseModifier: ViewModifier {
    @State private var phase: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .scaleEffect(1 + 0.015 * phase)
            .opacity(0.94 + 0.06 * phase)
            .onAppear {
                withAnimation(.easeInOut(duration: glowPulseDuration).repeatForever(autoreverses: true)) {
                    phase = 1
                }
            }
    }
}

struct ConditionalGlowPulse: ViewModifier {
    var active: Bool

    func body(content: Content) -> some View {
        if active {
            content.modifier(GlowPulseModifier())
        } else {
            content
        }
    }
}

extension View {
    func glowPulse() -> some View {
        modifier(GlowPulseModifier())
    }
}
