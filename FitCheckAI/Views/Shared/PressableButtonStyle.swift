//
//  PressableButtonStyle.swift
//  FitCheckAI
//

import SwiftUI

// MARK: - Shared press feedback constants (used app-wide)

private enum PressFeedback {
    static let scalePressed: CGFloat = 0.97
    static let opacityPressed: Double = 0.92
    static let animation: Animation = .easeOut(duration: 0.12)
}

/// Reusable global press animation: slight scale + opacity when pressed.
/// Apply at the app root so all buttons inherit this feedback unless they use an explicit style.
struct PressableButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? PressFeedback.scalePressed : 1.0)
            .opacity(configuration.isPressed ? PressFeedback.opacityPressed : 1.0)
            .animation(PressFeedback.animation, value: configuration.isPressed)
    }
}

/// Prominent filled button (accent) with press feedback. Use instead of .buttonStyle(.borderedProminent).tint(...).
/// Apply to label that already has .frame(maxWidth: .infinity) and .padding as needed.
struct BorderedProminentPressableStyle: ButtonStyle {
    var tint: Color = AppColors.accent

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(.white)
            .background(tint)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .scaleEffect(configuration.isPressed ? PressFeedback.scalePressed : 1.0)
            .opacity(configuration.isPressed ? PressFeedback.opacityPressed : 1.0)
            .animation(PressFeedback.animation, value: configuration.isPressed)
    }
}

/// Bordered/outline button with press feedback. Use instead of .buttonStyle(.bordered).tint(...).
struct BorderedPressableStyle: ButtonStyle {
    var tint: Color = AppColors.accent

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(tint)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(tint, lineWidth: 1.5)
            )
            .scaleEffect(configuration.isPressed ? PressFeedback.scalePressed : 1.0)
            .opacity(configuration.isPressed ? PressFeedback.opacityPressed : 1.0)
            .animation(PressFeedback.animation, value: configuration.isPressed)
    }
}

/// Plain button (no system chrome) with press feedback only. Use for custom-styled buttons that need tactile response.
struct PlainPressableStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? PressFeedback.scalePressed : 1.0)
            .opacity(configuration.isPressed ? PressFeedback.opacityPressed : 1.0)
            .animation(PressFeedback.animation, value: configuration.isPressed)
    }
}
