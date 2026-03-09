//
//  PurposeBadgeView.swift
//  FitCheckAI
//

import SwiftUI

struct PurposeBadgeView: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.caption)
            .fontWeight(.medium)
            .foregroundStyle(AppColors.accent)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(AppColors.accent.opacity(0.2))
            .clipShape(Capsule())
    }
}

enum PurposeBadge {
    static func label(for purpose: PhotoPurpose) -> String {
        switch purpose {
        case .outfit: return "Popular"
        case .dating: return "Best for matches"
        case .social: return "Boost engagement"
        case .professional: return "Work-ready"
        case .compare: return "Recommended"
        case .improveFit: return "Improve"
        }
    }
}
