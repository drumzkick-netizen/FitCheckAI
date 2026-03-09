//
//  GlassCardModifier.swift
//  FitCheckAI
//

import SwiftUI

/// Premium glass-style card appearance: rounded corners, subtle white border,
/// translucent ultraThinMaterial blur, soft drop shadow, and consistent padding.
struct GlassCardModifier: ViewModifier {
    var padding: CGFloat
    var cornerRadius: CGFloat

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.28), radius: 16, x: 0, y: 8)
    }
}

extension View {
    /// Applies a premium glass card style with default padding and corner radius.
    func glassCard() -> some View {
        modifier(GlassCardModifier(padding: 20, cornerRadius: 24))
    }

    /// Applies a premium glass card style with custom padding and corner radius.
    func glassCard(padding: CGFloat = 20, cornerRadius: CGFloat = 24) -> some View {
        modifier(GlassCardModifier(padding: padding, cornerRadius: cornerRadius))
    }
}
