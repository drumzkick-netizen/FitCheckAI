//
//  FadeSlideInModifier.swift
//  FitCheckAI
//

import SwiftUI

struct FadeSlideInModifier: ViewModifier {
    var delay: Double = 0
    var offset: CGFloat = 12

    @State private var isVisible = false

    func body(content: Content) -> some View {
        content
            .opacity(isVisible ? 1 : 0)
            .offset(y: isVisible ? 0 : offset)
            .onAppear {
                withAnimation(AppMotion.standardEase.delay(delay)) {
                    isVisible = true
                }
            }
    }
}

extension View {
    func fadeSlideIn(delay: Double = 0, offset: CGFloat = 12) -> some View {
        modifier(FadeSlideInModifier(delay: delay, offset: offset))
    }
}
