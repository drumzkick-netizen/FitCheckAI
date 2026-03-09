//
//  SettingsSectionCard.swift
//  FitCheckAI
//
//  Reusable settings section: label + premium card container.
//  Matches AppCard corner radius, padding, and stroke for consistency.
//

import SwiftUI

struct SettingsSectionCard<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title.uppercased())
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(AppColors.mutedText.opacity(0.9))
            AppCard(content: content)
        }
    }
}

#Preview {
    ZStack {
        AppColors.background.ignoresSafeArea()
        SettingsSectionCard(title: "App") {
            Text("Sample content")
                .foregroundStyle(.white)
        }
        .padding()
    }
    .preferredColorScheme(.dark)
}
