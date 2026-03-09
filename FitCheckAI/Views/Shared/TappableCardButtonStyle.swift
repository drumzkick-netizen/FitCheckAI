//
//  TappableCardButtonStyle.swift
//  FitCheckAI
//

import SwiftUI

/// Premium tap feedback for large action cards: slight scale-down on press with spring animation.
/// Use for Home screen Analyze a Fit and Photo Battle cards so the whole card feels responsive.
struct TappableCardButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .opacity(configuration.isPressed ? 0.92 : 1.0)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

// MARK: - TappableCard (delayed action so press animation is visible)

/// Wraps content in a tappable area that shows a brief scale-down on tap, then runs the action after a short delay.
/// Use this instead of Button when navigation would otherwise happen immediately and hide the press animation.
struct TappableCard<Content: View>: View {
    let action: () -> Void
    let content: Content

    @State private var isPressed = false

    private let pressDelay: Double = 0.1

    init(action: @escaping () -> Void, @ViewBuilder content: () -> Content) {
        self.action = action
        self.content = content()
    }

    var body: some View {
        content
            .scaleEffect(isPressed ? 0.97 : 1.0)
            .opacity(isPressed ? 0.92 : 1.0)
            .animation(.easeOut(duration: 0.12), value: isPressed)
            .contentShape(Rectangle())
            .onTapGesture {
                guard !isPressed else { return }
                isPressed = true
                DispatchQueue.main.asyncAfter(deadline: .now() + pressDelay) {
                    action()
                    isPressed = false
                }
            }
    }
}
