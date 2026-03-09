//
//  AppCard.swift
//  FitCheckAI
//

import SwiftUI

struct AppCard<Content: View>: View {
    let content: () -> Content

    init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
    }

    var body: some View {
        content()
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppColors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.white.opacity(0.06), lineWidth: 1)
            )
    }
}

struct AppCardWithGradient<Content: View>: View {
    let gradient: LinearGradient
    let content: () -> Content

    init(gradient: LinearGradient, @ViewBuilder content: @escaping () -> Content) {
        self.gradient = gradient
        self.content = content
    }

    var body: some View {
        content()
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                ZStack {
                    AppColors.cardBackground
                    gradient.opacity(0.15)
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )
    }
}
